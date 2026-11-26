package fr.nautilink.nautilink

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Canaux natifs de la vraie application :
 * - `fr.nautilink/sms` : SMS envoyés automatiquement par la carte SIM (SMS SOS
 *   et SMS de positions automatiques, RG-SOS-16, RG-SMS-03), avec l'accusé
 *   d'envoi et l'accusé de réception (RG-SOS-12) ; MMS prérempli (RG-SMS-05).
 *   Les SMS partent par la SIM choisie pour les SMS dans les réglages du
 *   téléphone (RG-AND-07).
 * - `fr.nautilink/telephone` : exclusion de l'optimisation de la batterie et
 *   marque du téléphone (RG-GPS-05), autorisation des notifications
 *   (Android 13 et plus), navigation en cours pour la notification après un
 *   redémarrage (RG-NAV-12, D-51).
 */
class MainActivity : FlutterActivity() {
    private var sms: MethodChannel? = null
    private var reponsePermission: MethodChannel.Result? = null
    private var permissionDemandee: String? = null

    companion object {
        private const val ENVOYE = "fr.nautilink.SMS_ENVOYE"
        private const val RECU = "fr.nautilink.SMS_RECU"
        private const val DEMANDE = 7301
    }

    /** Parties d'un SMS long : état final quand toutes ont répondu. */
    private class Suivi(val parties: Int) {
        var envoyees = 0
        var recues = 0
        var echec = false
    }

    private val suivis = HashMap<String, Suivi>()

    private val recepteur = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getStringExtra("id") ?: return
            val s = suivis[id] ?: return
            when (intent.action) {
                ENVOYE -> {
                    if (resultCode != Activity.RESULT_OK) {
                        if (!s.echec) {
                            s.echec = true
                            statut(id, "echec")
                        }
                        return
                    }
                    s.envoyees++
                    if (s.envoyees == s.parties && !s.echec) statut(id, "accepte_pour_envoi")
                }
                RECU -> {
                    s.recues++
                    if (s.recues == s.parties && !s.echec) {
                        statut(id, "livraison_confirmee")
                        suivis.remove(id)
                    }
                }
            }
        }
    }

    private fun statut(id: String, statut: String) {
        sms?.invokeMethod("statut", mapOf("id" to id, "statut" to statut))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val filtre = IntentFilter().apply {
            addAction(ENVOYE)
            addAction(RECU)
        }
        ContextCompat.registerReceiver(this, recepteur, filtre, ContextCompat.RECEIVER_NOT_EXPORTED)

        val messager = flutterEngine.dartExecutor.binaryMessenger
        sms = MethodChannel(messager, "fr.nautilink/sms").apply {
            setMethodCallHandler { appel, resultat ->
                when (appel.method) {
                    "autorise" -> resultat.success(accordee(Manifest.permission.SEND_SMS))
                    "demander" -> demander(Manifest.permission.SEND_SMS, resultat)
                    "envoyer" -> try {
                        envoyer(
                            appel.argument<String>("id")!!,
                            appel.argument<String>("numero")!!,
                            appel.argument<String>("texte")!!,
                        )
                        resultat.success(null)
                    } catch (e: Exception) {
                        resultat.error("envoi", e.message, null)
                    }
                    "ouvrirMms" -> resultat.success(
                        ouvrirMms(
                            appel.argument<List<String>>("numeros") ?: emptyList(),
                            appel.argument<String>("texte") ?: "",
                            appel.argument<String>("image")!!,
                        ),
                    )
                    else -> resultat.notImplemented()
                }
            }
        }

        MethodChannel(messager, "fr.nautilink/telephone").setMethodCallHandler { appel, resultat ->
            when (appel.method) {
                "batterieExclue" -> resultat.success(batterieExclue())
                "demanderExclusionBatterie" -> resultat.success(demanderExclusionBatterie())
                "fabricant" -> resultat.success(Build.MANUFACTURER ?: "")
                "notificationsAutorisees" -> resultat.success(
                    Build.VERSION.SDK_INT < 33 || accordee(Manifest.permission.POST_NOTIFICATIONS),
                )
                "demanderNotifications" ->
                    if (Build.VERSION.SDK_INT < 33) resultat.success(true)
                    else demander(Manifest.permission.POST_NOTIFICATIONS, resultat)
                else -> resultat.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(recepteur)
        } catch (_: IllegalArgumentException) {
        }
        super.onDestroy()
    }

    private fun accordee(p: String) =
        ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED

    private fun demander(p: String, resultat: MethodChannel.Result) {
        if (accordee(p)) {
            resultat.success(true)
            return
        }
        reponsePermission?.success(false)
        reponsePermission = resultat
        permissionDemandee = p
        ActivityCompat.requestPermissions(this, arrayOf(p), DEMANDE)
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, resultats: IntArray) {
        super.onRequestPermissionsResult(code, permissions, resultats)
        if (code != DEMANDE) return
        val p = permissionDemandee
        reponsePermission?.success(p != null && accordee(p))
        reponsePermission = null
        permissionDemandee = null
    }

    @Suppress("DEPRECATION")
    private fun gestionnaireSms(): SmsManager =
        if (Build.VERSION.SDK_INT >= 31) getSystemService(SmsManager::class.java)
        else SmsManager.getDefault()

    private fun envoyer(id: String, numero: String, texte: String) {
        if (!accordee(Manifest.permission.SEND_SMS)) throw SecurityException("SEND_SMS refusée")
        val g = gestionnaireSms()
        val parties = g.divideMessage(texte)
        suivis[id] = Suivi(parties.size)
        val drapeaux = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        fun intention(action: String, i: Int) = PendingIntent.getBroadcast(
            this,
            (id + action + i).hashCode(),
            Intent(action).setPackage(packageName).putExtra("id", id),
            drapeaux,
        )
        val envois = ArrayList((0 until parties.size).map { intention(ENVOYE, it) })
        val receptions = ArrayList((0 until parties.size).map { intention(RECU, it) })
        if (parties.size == 1) {
            g.sendTextMessage(numero, null, texte, envois[0], receptions[0])
        } else {
            g.sendMultipartTextMessage(numero, null, parties, envois, receptions)
        }
    }

    /** MMS prérempli : photo jointe, texte et destinataires (RG-SMS-05). */
    private fun ouvrirMms(numeros: List<String>, texte: String, image: String): Boolean {
        return try {
            val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fichiers", File(image))
            val i = Intent(Intent.ACTION_SEND).apply {
                type = "image/jpeg"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra("sms_body", texte)
                putExtra("address", numeros.joinToString(";"))
                putExtra(Intent.EXTRA_TEXT, texte)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(i, null))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun batterieExclue(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /** Demande d'exclusion de l'optimisation de la batterie (RG-GPS-05). */
    private fun demanderExclusionBatterie(): Boolean {
        if (batterieExclue()) return true
        return try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName")),
            )
            true
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                true
            } catch (_: Exception) {
                false
            }
        }
    }
}

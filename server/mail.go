package main

import (
	"errors"
	"fmt"
	"mime"
	"net"
	"net/smtp"
	"strings"
	"time"
)

// envoyerMail : envoi par le relais d'e-mails de pi-appliance (D-62), joignable
// seulement par les conteneurs, sans mot de passe (TODO-2.74 de pi-appliance).
func envoyerMail(cfg config, a, sujet, texte string) error {
	if cfg.SMTPHote == "" {
		return errors.New("relais d'e-mails non réglé (NAUTILINK_SMTP_HOTE)")
	}
	if strings.ContainsAny(a, "\r\n") || !strings.Contains(a, "@") {
		return fmt.Errorf("adresse invalide : %q", a)
	}
	msg := "From: NautiLink <" + cfg.Expediteur + ">\r\n" +
		"To: " + a + "\r\n" +
		"Subject: " + mime.QEncoding.Encode("utf-8", sujet) + "\r\n" +
		"Date: " + time.Now().Format(time.RFC1123Z) + "\r\n" +
		"MIME-Version: 1.0\r\n" +
		"Content-Type: text/plain; charset=utf-8\r\n" +
		"Content-Transfer-Encoding: 8bit\r\n\r\n" +
		strings.ReplaceAll(texte, "\n", "\r\n")
	return smtp.SendMail(net.JoinHostPort(cfg.SMTPHote, cfg.SMTPPort), nil,
		cfg.Expediteur, []string{a}, []byte(msg))
}

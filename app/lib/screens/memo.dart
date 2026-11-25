import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';

/// Ouvre le mémo sécurité en mer du site (TODO-3.12).
Future<void> openSecurityMemo(BuildContext context) =>
    launchUrl(Uri.parse(securityMemoUrl), mode: LaunchMode.externalApplication);

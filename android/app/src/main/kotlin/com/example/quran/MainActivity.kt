package com.sofian.quran

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Autorise l'app à dessiner derrière les barres système
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Nécessaire pour contrôler la couleur de la barre de navigation
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION)

        // Barre de navigation 80 % transparente (alpha 51 = 0x33)
        window.navigationBarColor = Color.argb(51, 0, 0, 0)

        // Android 10+ : désactive le voile de contraste automatique
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    // Réapplique au retour au premier plan (certains launchers réinitialisent la couleur)
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            window.navigationBarColor = Color.argb(51, 0, 0, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
        }
    }
}

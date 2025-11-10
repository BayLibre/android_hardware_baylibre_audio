# BayLibre Generic Audio HAL (AIDL)

## Description

Ce HAL audio AIDL générique est conçu pour être facilement adaptable à différentes plateformes (Amlogic, Rockchip, etc.). Il est basé sur l'implémentation de référence AOSP et a été modifié pour offrir plus de flexibilité.

## Architecture

Le HAL supporte plusieurs modules audio :

- **Primary/ALSA** : Module principal utilisant ALSA pour l'audio de base
- **USB** : Support des périphériques audio USB
- **Bluetooth** : Support des casques et enceintes Bluetooth
- **R_submix** : Capture audio système (remote submix)
- **Stub** : Module de test/développement

## Utilisation multi-plateforme

### Configuration par plateforme

Pour adapter ce HAL à votre plateforme spécifique :

1. **Configuration audio policy** :
   - Modifiez les fichiers XML dans `config/audioPolicy/` selon votre hardware
   - Définissez vos périphériques audio, ports, et routes

2. **Configuration ALSA** :
   - Les modules ALSA dans `alsa/` peuvent être adaptés pour votre carte son
   - Modifiez les mixers et les configurations PCM selon vos besoins

3. **Modules optionnels** :
   - Activez/désactivez les modules dans le fichier manifest VINTF selon vos besoins
   - Commentez les modules non utilisés dans `android.hardware.audio.service-aidl.xml`

### Propriétés système

Le HAL peut être configuré via des propriétés système :

```
# Exemples de propriétés (à définir dans votre build)
persist.vendor.audio.primary.device=0
persist.vendor.audio.usb.enabled=true
persist.vendor.audio.bluetooth.enabled=true
```

### Build pour une plateforme spécifique

Dans votre fichier `device.mk` de plateforme :

```make
# Inclure le HAL audio BayLibre
PRODUCT_PACKAGES += \\
    android.hardware.audio.service-aidl.baylibre \\
    android.hardware.audio.effect.service-aidl.baylibre \\
    android.hardware.audio.service-aidl.xml

# Configuration audio policy spécifique à votre plateforme
PRODUCT_COPY_FILES += \\
    device/yourvendor/yourdevice/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml
```

## Structure des fichiers

- `main.cpp` : Point d'entrée du service audio
- `Module.cpp` : Implémentation principale du module audio
- `alsa/` : Implémentation ALSA générique
- `bluetooth/` : Support Bluetooth
- `usb/` : Support USB audio
- `primary/` : Module audio principal
- `r_submix/` : Remote submix
- `stub/` : Module stub pour tests
- `config/` : Fichiers de configuration XML

## Adaptation à une nouvelle plateforme

1. Créez une configuration audio policy XML pour votre plateforme
2. Ajustez les paramètres ALSA (cartes, périphériques, mixers)
3. Compilez le HAL avec votre configuration
4. Testez avec `adb shell dumpsys media.audio_policy`

## Support

Pour toute question ou contribution, contactez l'équipe BayLibre.

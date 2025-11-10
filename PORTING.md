# Guide de portage du HAL Audio BayLibre

Ce guide explique comment porter le HAL audio générique BayLibre sur une nouvelle plateforme.

## Étapes de portage

### 1. Identifier le matériel audio

Sur votre device, identifiez les périphériques audio disponibles :

```bash
adb shell cat /proc/asound/cards
adb shell cat /proc/asound/devices
adb shell cat /proc/asound/pcm
```

Notez les numéros de cartes et de périphériques pour chaque sortie/entrée audio.

### 2. Créer la configuration audio policy

Créez un fichier `audio_policy_configuration.xml` pour votre plateforme dans votre device tree :

```
device/yourvendor/yourdevice/audio/audio_policy_configuration.xml
```

Structure de base :

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<audioPolicyConfiguration>
    <modules>
        <!-- Module primaire pour l'audio ALSA -->
        <module name="primary" halVersion="AIDL">
            <attachedDevices>
                <item>Speaker</item>
                <item>Built-In Mic</item>
            </attachedDevices>
            <devicePorts>
                <!-- Définir vos périphériques audio ici -->
                <devicePort tagName="Speaker" type="AUDIO_DEVICE_OUT_SPEAKER" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </devicePort>
                <devicePort tagName="Built-In Mic" type="AUDIO_DEVICE_IN_BUILTIN_MIC" role="source">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_IN_STEREO"/>
                </devicePort>
            </devicePorts>
            <!-- Mixer ports (connections logiques) -->
            <mixPorts>
                <mixPort name="primary output" role="source" flags="AUDIO_OUTPUT_FLAG_PRIMARY">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </mixPort>
                <mixPort name="primary input" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_IN_STEREO"/>
                </mixPort>
            </mixPorts>
            <!-- Routes (connexions entre mixer et devices) -->
            <routes>
                <route type="mix" sink="Speaker" sources="primary output"/>
                <route type="mix" sink="primary input" sources="Built-In Mic"/>
            </routes>
        </module>

        <!-- Modules optionnels -->
        <!-- USB Audio -->
        <xi:include href="usb_audio_policy_configuration.xml"/>

        <!-- Bluetooth -->
        <xi:include href="bluetooth_audio_policy_configuration.xml"/>

        <!-- Remote Submix (pour capture système) -->
        <xi:include href="r_submix_audio_policy_configuration.xml"/>
    </modules>
</audioPolicyConfiguration>
```

### 3. Adapter les paramètres ALSA

Si nécessaire, créez un fichier de configuration pour les chemins mixer ALSA :

```
device/yourvendor/yourdevice/audio/mixer_paths.xml
```

### 4. Configurer le device.mk

Dans votre `device.mk`, ajoutez :

```make
# Audio HAL
PRODUCT_PACKAGES += \\
    android.hardware.audio.service-aidl.baylibre \\
    android.hardware.audio.effect.service-aidl.baylibre \\
    android.hardware.audio.service-aidl.xml \\
    audio.primary.$(TARGET_BOARD_PLATFORM)

# Audio configuration
PRODUCT_COPY_FILES += \\
    device/yourvendor/yourdevice/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \\
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \\
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \\
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \\
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \\
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration.xml

# Audio properties (optionnel, voir platform_configs/)
-include hardware/baylibre/audio/platform_configs/yourplatform/platform_properties.mk
```

### 5. Tester le HAL

Après le build et le flash :

```bash
# Vérifier que le service audio est démarré
adb shell ps -A | grep audio

# Vérifier la configuration chargée
adb shell dumpsys media.audio_policy

# Tester la lecture audio
adb shell tinymix
adb shell tinyplay /system/media/audio/alarms/Argon.ogg
```

## Adaptation spécifique à la plateforme

### Amlogic

Pour les SoCs Amlogic, référez-vous à `platform_configs/amlogic/` pour les propriétés recommandées.

Spécificités Amlogic :
- Support SPDIF et HDMI audio
- Cartes audio généralement nommées "AMLAUGESOUND" ou similaire
- Périphériques audio multiples (I2S, SPDIF, HDMI)

### Rockchip

Pour les SoCs Rockchip, référez-vous à `platform_configs/rockchip/` pour les propriétés recommandées.

Spécificités Rockchip :
- Codecs audio variés (ES8316, RT5640, etc.)
- Configuration HDMI audio via CEC
- Support des cartes audio rockchip-sound

## Debugging

### Logs audio

```bash
adb logcat -s AudioHAL:V AHAL_Main:V audio_hw:V
```

### Propriétés debug

```bash
adb shell setprop persist.vendor.audio.hal.debug true
adb shell setprop log.tag.AudioHAL VERBOSE
```

### Vérifier les périphériques ALSA

```bash
adb shell cat /proc/asound/cards
adb shell cat /proc/asound/pcm
adb shell tinymix -D 0  # Liste les contrôles de la carte 0
```

## Support

Pour toute question sur le portage, contactez l'équipe BayLibre ou consultez la documentation AOSP audio :
https://source.android.com/docs/core/audio

# Gestion des contrôles Mixer ALSA dans le HAL Audio BayLibre

## Architecture

Le HAL audio utilise une architecture en couches pour gérer les contrôles mixer ALSA (volume, mute, gain, etc.) :

```
Android Framework (AudioManager, AudioService)
          ↓
  AIDL Interface (IModule)
          ↓
     Module (Module.cpp)
          ↓
  PrimaryMixer / UsbAlsaMixerControl
          ↓
     Mixer (alsa/Mixer.cpp)
          ↓
    TinyAlsa Library
          ↓
     ALSA Kernel Driver
```

## Classes principales

### 1. `alsa::Mixer` (alsa/Mixer.h, alsa/Mixer.cpp)

Classe de base qui encapsule l'accès aux contrôles mixer ALSA via TinyAlsa.

**Contrôles supportés :**

```cpp
enum Control {
    MASTER_SWITCH,  // Master mute (Master Playback Switch)
    MASTER_VOLUME,  // Master volume (Master Playback Volume)
    HW_VOLUME,      // Hardware volume (Headphone/Headset/PCM Playback Volume)
    MIC_SWITCH,     // Mic mute (Capture Switch)
    MIC_GAIN,       // Mic gain (Capture Volume)
};
```

**Mapping des noms de contrôles ALSA :**

Le HAL recherche automatiquement les contrôles ALSA par nom dans cet ordre :

```cpp
kPossibleControls = {
    {MASTER_SWITCH, {{"Master Playback Switch", MIXER_CTL_TYPE_BOOL}}},
    {MASTER_VOLUME, {{"Master Playback Volume", MIXER_CTL_TYPE_INT}}},
    {HW_VOLUME, {
        {"Headphone Playback Volume", MIXER_CTL_TYPE_INT},
        {"Headset Playback Volume", MIXER_CTL_TYPE_INT},
        {"PCM Playback Volume", MIXER_CTL_TYPE_INT}
    }},
    {MIC_SWITCH, {{"Capture Switch", MIXER_CTL_TYPE_BOOL}}},
    {MIC_GAIN, {{"Capture Volume", MIXER_CTL_TYPE_INT}}}
};
```

**API publique :**

```cpp
// Volume master (0.0 à 1.0)
ndk::ScopedAStatus setMasterVolume(float volume);
ndk::ScopedAStatus getMasterVolume(float* volume);

// Mute master
ndk::ScopedAStatus setMasterMute(bool muted);
ndk::ScopedAStatus getMasterMute(bool* muted);

// Gain microphone (0.0 à 1.0)
ndk::ScopedAStatus setMicGain(float gain);
ndk::ScopedAStatus getMicGain(float* gain);

// Mute microphone
ndk::ScopedAStatus setMicMute(bool muted);
ndk::ScopedAStatus getMicMute(bool* muted);

// Volumes par canal
ndk::ScopedAStatus setVolumes(const std::vector<float>& volumes);
ndk::ScopedAStatus getVolumes(std::vector<float>* volumes);
```

**Conversion des valeurs :**

Le HAL effectue automatiquement les conversions :
- Android utilise des valeurs float de 0.0 à 1.0
- ALSA utilise des pourcentages de 0 à 100
- Conversion : `percent = floor(volume * 100)`

**Thread-safety :**

Tous les accès au mixer ALSA sont protégés par un mutex (`mMixerAccess`) car TinyAlsa n'est pas thread-safe.

### 2. `primary::PrimaryMixer` (primary/PrimaryMixer.h, primary/PrimaryMixer.cpp)

Singleton qui hérite de `alsa::Mixer` pour le module audio primaire.

```cpp
class PrimaryMixer : public alsa::Mixer {
public:
    static constexpr int kAlsaCard = 0;    // Carte ALSA par défaut
    static constexpr int kAlsaDevice = 0;  // Device ALSA par défaut

    static PrimaryMixer& getInstance();
private:
    PrimaryMixer() : alsa::Mixer(kAlsaCard) {}
};
```

**Utilisation :**

```cpp
// Accès au mixer singleton
auto& mixer = primary::PrimaryMixer::getInstance();

// Définir le volume master
mixer.setMasterVolume(0.8f);  // 80%

// Muter
mixer.setMasterMute(true);
```

### 3. `Module` (Module.cpp, include/core-impl/Module.h)

Le module audio AIDL expose les contrôles mixer au framework Android.

**Méthodes AIDL :**

```cpp
// Implémentées dans Module.cpp
ndk::ScopedAStatus getMasterMute(bool* _aidl_return);
ndk::ScopedAStatus setMasterMute(bool in_mute);
ndk::ScopedAStatus getMasterVolume(float* _aidl_return);
ndk::ScopedAStatus setMasterVolume(float in_volume);
```

**Mécanisme :**

1. Le framework Android appelle `setMasterVolume()` via AIDL
2. `Module::setMasterVolume()` :
   - Valide la valeur (0.0 ≤ volume ≤ 1.0)
   - Appelle la méthode virtuelle `onMasterVolumeChanged()`
   - Stocke la valeur dans `mMasterVolume`
3. Les classes dérivées (ModuleUsb, etc.) peuvent override `onMasterVolumeChanged()`

### 4. `StreamPrimary` (primary/StreamPrimary.cpp)

Les streams audio utilisent aussi le mixer pour les contrôles par stream.

**Gain microphone (input) :**

```cpp
ndk::ScopedAStatus StreamInPrimary::getHwGain(std::vector<float>* _aidl_return) {
    if (mHwGains.empty()) {
        float gain;
        // Lire le gain depuis le mixer ALSA
        RETURN_STATUS_IF_ERROR(primary::PrimaryMixer::getInstance().getMicGain(&gain));
        _aidl_return->resize(mChannelCount, gain);
        RETURN_STATUS_IF_ERROR(setHwGainImpl(*_aidl_return));
    }
    *_aidl_return = mHwGains;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus StreamInPrimary::setHwGain(const std::vector<float>& in_channelGains) {
    // Appliquer le gain au mixer ALSA
    if (auto status = primary::PrimaryMixer::getInstance().setMicGain(in_channelGains[0]);
        !status.isOk()) {
        return status;
    }
    // Vérifier la valeur effective (rounding)
    float gain;
    RETURN_STATUS_IF_ERROR(primary::PrimaryMixer::getInstance().getMicGain(&gain));
    mHwGains.assign(mChannelCount, gain);
    return ndk::ScopedAStatus::ok();
}
```

**Volume hardware (output) :**

```cpp
ndk::ScopedAStatus StreamOutPrimary::setHwVolume(const std::vector<float>& in_channelVolumes) {
    RETURN_STATUS_IF_ERROR(setHwVolumeImpl(in_channelVolumes));
    // Appliquer au mixer ALSA
    if (auto status = primary::PrimaryMixer::getInstance().setVolumes(in_channelVolumes);
        !status.isOk()) {
        return status;
    }
    std::vector<float> volumes;
    RETURN_STATUS_IF_ERROR(primary::PrimaryMixer::getInstance().getVolumes(&volumes));
    mHwVolumes.assign(mChannelCount, volumes[0]);
    return ndk::ScopedAStatus::ok();
}
```

### 5. `UsbAlsaMixerControl` (usb/UsbAlsaMixerControl.h, usb/UsbAlsaMixerControl.cpp)

Gère les mixers pour plusieurs périphériques USB simultanément.

```cpp
class UsbAlsaMixerControl {
public:
    void setDeviceConnectionState(int card, bool masterMuted,
                                  float masterVolume, bool connected);
    ndk::ScopedAStatus setMasterMute(bool mute);
    ndk::ScopedAStatus setMasterVolume(float volume);

private:
    std::mutex mLock;
    std::map<int, std::shared_ptr<alsa::Mixer>> mMixerControls;
};
```

**Fonctionnement :**

- Chaque carte USB a son propre mixer `alsa::Mixer(card)`
- Lors de la connexion d'un device USB, un mixer est créé
- Les changements de volume/mute sont appliqués à tous les mixers USB connectés

## Personnalisation par plateforme

### Adapter les noms de contrôles ALSA

Si votre plateforme utilise des noms différents pour les contrôles mixer, vous devez modifier `alsa/Mixer.cpp` :

```cpp
// Exemple pour Amlogic avec contrôles spécifiques
const std::map<Mixer::Control, std::vector<Mixer::ControlNamesAndExpectedCtlType>>
        Mixer::kPossibleControls = {
    {MASTER_SWITCH, {
        {"Master Playback Switch", MIXER_CTL_TYPE_BOOL},
        {"AIU HDMI Playback Switch", MIXER_CTL_TYPE_BOOL}  // Ajout Amlogic
    }},
    {MASTER_VOLUME, {
        {"Master Playback Volume", MIXER_CTL_TYPE_INT},
        {"AIU HDMI Playback Volume", MIXER_CTL_TYPE_INT}   // Ajout Amlogic
    }},
    // ...
};
```

### Changer le numéro de carte ALSA par défaut

Modifier `primary/PrimaryMixer.h` :

```cpp
class PrimaryMixer : public alsa::Mixer {
public:
    static constexpr int kAlsaCard = 0;    // Changer selon votre plateforme
    static constexpr int kAlsaDevice = 0;
    // ...
};
```

Ou utiliser une propriété système (modification nécessaire) :

```cpp
// Dans PrimaryMixer.cpp
PrimaryMixer::PrimaryMixer()
    : alsa::Mixer(android::base::GetIntProperty("persist.vendor.audio.primary.card", 0)) {
}
```

## Debugging

### Lister les contrôles mixer disponibles

```bash
adb shell tinymix -D 0  # Carte 0
adb shell tinymix -D 1  # Carte 1
```

### Obtenir/définir un contrôle

```bash
# Obtenir la valeur
adb shell tinymix "Master Playback Volume"

# Définir la valeur
adb shell tinymix "Master Playback Volume" 80

# Mute
adb shell tinymix "Master Playback Switch" 0
```

### Logs HAL

```bash
adb logcat -s AHAL_AlsaMixer:V AHAL_PrimaryMixer:V
```

Les logs montrent :
- Les contrôles mixer trouvés au démarrage
- Les appels setMasterVolume/setMasterMute
- Les erreurs d'accès aux contrôles

### Test via AudioManager

```bash
# Via adb
adb shell media volume --stream 3 --set 10  # Volume à 10/15

# Via code Java/Kotlin
AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
am.setStreamVolume(AudioManager.STREAM_MUSIC, 10, 0);
```

## Limitations actuelles

1. **Contrôles codés en dur** : Les noms de contrôles ALSA sont codés en dur. Pour ajouter de nouveaux contrôles, il faut modifier `kPossibleControls`.

2. **Pas de routing mixer** : Le HAL ne gère pas les chemins de routing ALSA (mixer paths). Pour cela, il faut intégrer un gestionnaire de mixer paths (comme audio_route ou mixer_paths.xml).

3. **Volume par canal limité** : Le HAL applique le même volume à tous les canaux d'un contrôle multi-canal.

4. **Pas de courbe de volume** : Le HAL utilise une conversion linéaire (0-100%). Pour des courbes logarithmiques, il faut modifier les méthodes de conversion.

## Améliorations possibles

1. **Fichier de configuration XML** pour les noms de contrôles
2. **Support de mixer_paths.xml** pour le routing
3. **Courbes de volume personnalisables**
4. **Support des contrôles enum ALSA**
5. **Propriétés système pour la carte ALSA par défaut**

## Références

- Code source : `alsa/Mixer.cpp`, `primary/PrimaryMixer.cpp`
- TinyAlsa documentation : https://github.com/tinyalsa/tinyalsa
- ALSA mixer API : https://www.alsa-project.org/alsa-doc/alsa-lib/group___mixer.html

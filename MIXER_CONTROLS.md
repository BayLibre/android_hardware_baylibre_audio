# ALSA Mixer Controls Management in BayLibre Audio HAL

## Architecture

The audio HAL uses a layered architecture to manage ALSA mixer controls (volume, mute, gain, etc.):

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

## Main Classes

### 1. `alsa::Mixer` (alsa/Mixer.h, alsa/Mixer.cpp)

Base class that encapsulates ALSA mixer control access via TinyAlsa.

**Supported Controls:**

```cpp
enum Control {
    MASTER_SWITCH,  // Master mute (Master Playback Switch)
    MASTER_VOLUME,  // Master volume (Master Playback Volume)
    HW_VOLUME,      // Hardware volume (Headphone/Headset/PCM Playback Volume)
    MIC_SWITCH,     // Mic mute (Capture Switch)
    MIC_GAIN,       // Mic gain (Capture Volume)
};
```

**ALSA Control Names Mapping:**

The HAL can load control names from an XML configuration file (`mixer_controls.xml`) or use built-in defaults:

**Default mappings** (alsa/Mixer.cpp:48-58):
```cpp
{MASTER_SWITCH, {{"Master Playback Switch", MIXER_CTL_TYPE_BOOL}}},
{MASTER_VOLUME, {{"Master Playback Volume", MIXER_CTL_TYPE_INT}}},
{HW_VOLUME, {
    {"Headphone Playback Volume", MIXER_CTL_TYPE_INT},
    {"Headset Playback Volume", MIXER_CTL_TYPE_INT},
    {"PCM Playback Volume", MIXER_CTL_TYPE_INT}
}},
{MIC_SWITCH, {{"Capture Switch", MIXER_CTL_TYPE_BOOL}}},
{MIC_GAIN, {{"Capture Volume", MIXER_CTL_TYPE_INT}}}
```

**Configuration via XML** (alsa/Mixer.cpp:63-153):

The HAL loads control names from `/vendor/etc/mixer_controls.xml` at startup. If the file is not found or cannot be parsed, it falls back to the built-in defaults above.

**Public API:**

```cpp
// Master volume (0.0 to 1.0)
ndk::ScopedAStatus setMasterVolume(float volume);
ndk::ScopedAStatus getMasterVolume(float* volume);

// Master mute
ndk::ScopedAStatus setMasterMute(bool muted);
ndk::ScopedAStatus getMasterMute(bool* muted);

// Microphone gain (0.0 to 1.0)
ndk::ScopedAStatus setMicGain(float gain);
ndk::ScopedAStatus getMicGain(float* gain);

// Microphone mute
ndk::ScopedAStatus setMicMute(bool muted);
ndk::ScopedAStatus getMicMute(bool* muted);

// Per-channel volumes
ndk::ScopedAStatus setVolumes(const std::vector<float>& volumes);
ndk::ScopedAStatus getVolumes(std::vector<float>* volumes);
```

**Value Conversion:**

The HAL automatically converts between:
- Android uses float values from 0.0 to 1.0
- ALSA uses percentages from 0 to 100
- Conversion: `percent = floor(volume * 100)`

**Thread-safety:**

All ALSA mixer accesses are protected by a mutex (`mMixerAccess`) because TinyAlsa is not thread-safe.

### 2. `primary::PrimaryMixer` (primary/PrimaryMixer.h, primary/PrimaryMixer.cpp)

Singleton that inherits from `alsa::Mixer` for the primary audio module.

```cpp
class PrimaryMixer : public alsa::Mixer {
public:
    static constexpr int kDefaultAlsaCard = 0;
    static constexpr int kDefaultAlsaDevice = 0;

    static PrimaryMixer& getInstance();
    static int getAlsaCard();    // Reads persist.vendor.audio.primary.card
    static int getAlsaDevice();  // Reads persist.vendor.audio.primary.device
private:
    PrimaryMixer();
};
```

**Configuration via Properties** (primary/PrimaryMixer.cpp:27-44):

The mixer reads the ALSA card number from system property at initialization:

```cpp
int card = ::android::base::GetIntProperty("persist.vendor.audio.primary.card",
                                            kDefaultAlsaCard);
```

**Usage:**

```cpp
// Access singleton mixer
auto& mixer = primary::PrimaryMixer::getInstance();

// Set master volume
mixer.setMasterVolume(0.8f);  // 80%

// Mute
mixer.setMasterMute(true);
```

### 3. `Module` (Module.cpp, include/core-impl/Module.h)

The AIDL audio module exposes mixer controls to the Android framework.

**AIDL Methods:**

```cpp
// Implemented in Module.cpp:1459-1500
ndk::ScopedAStatus getMasterMute(bool* _aidl_return);
ndk::ScopedAStatus setMasterMute(bool in_mute);
ndk::ScopedAStatus getMasterVolume(float* _aidl_return);
ndk::ScopedAStatus setMasterVolume(float in_volume);
```

**Mechanism:**

1. Android framework calls `setMasterVolume()` via AIDL
2. `Module::setMasterVolume()`:
   - Validates value (0.0 ≤ volume ≤ 1.0)
   - Calls virtual method `onMasterVolumeChanged()`
   - Stores value in `mMasterVolume`
3. Derived classes (ModuleUsb, etc.) can override `onMasterVolumeChanged()`

### 4. `StreamPrimary` (primary/StreamPrimary.cpp)

Audio streams can also control mixer settings per-stream.

**Microphone gain (input):**

```cpp
ndk::ScopedAStatus StreamInPrimary::getHwGain(std::vector<float>* _aidl_return) {
    if (mHwGains.empty()) {
        float gain;
        // Read gain from ALSA mixer
        RETURN_STATUS_IF_ERROR(primary::PrimaryMixer::getInstance().getMicGain(&gain));
        _aidl_return->resize(mChannelCount, gain);
        RETURN_STATUS_IF_ERROR(setHwGainImpl(*_aidl_return));
    }
    *_aidl_return = mHwGains;
    return ndk::ScopedAStatus::ok();
}

ndk::ScopedAStatus StreamInPrimary::setHwGain(const std::vector<float>& in_channelGains) {
    // Apply gain to ALSA mixer
    if (auto status = primary::PrimaryMixer::getInstance().setMicGain(in_channelGains[0]);
        !status.isOk()) {
        return status;
    }
    // Verify effective value (rounding)
    float gain;
    RETURN_STATUS_IF_ERROR(primary::PrimaryMixer::getInstance().getMicGain(&gain));
    mHwGains.assign(mChannelCount, gain);
    return ndk::ScopedAStatus::ok();
}
```

**Hardware volume (output):**

```cpp
ndk::ScopedAStatus StreamOutPrimary::setHwVolume(const std::vector<float>& in_channelVolumes) {
    RETURN_STATUS_IF_ERROR(setHwVolumeImpl(in_channelVolumes));
    // Apply to ALSA mixer
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

Manages mixers for multiple USB devices simultaneously.

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

**Operation:**

- Each USB card has its own mixer `alsa::Mixer(card)`
- When a USB device connects, a mixer is created
- Volume/mute changes are applied to all connected USB mixers

## Platform Customization

### Customize ALSA Control Names

Create a `mixer_controls.xml` file for your platform:

```xml
<?xml version="1.0" encoding="utf-8"?>
<mixerControls>
    <!-- Example for Amlogic with specific controls -->
    <control function="MASTER_VOLUME" type="int">
        <name>HDMI Playback Volume</name>
        <name>TOHDMITX Playback Volume</name>
        <name>Master Playback Volume</name>
    </control>

    <control function="MASTER_SWITCH" type="bool">
        <name>TOHDMITX Switch</name>
        <name>HDMI Playback Switch</name>
    </control>
    <!-- Add more controls -->
</mixerControls>
```

Install in device.mk:

```make
PRODUCT_COPY_FILES += \
    device/yourvendor/yourdevice/audio/mixer_controls.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml
```

### Change Default ALSA Card Number

Use system properties (no code modification needed):

```make
# In device.mk
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.audio.primary.card=1
```

Or set at runtime:

```bash
adb shell setprop persist.vendor.audio.primary.card 1
adb shell stop vendor.audio-hal-aidl
adb shell start vendor.audio-hal-aidl
```

## Debugging

### List Available Mixer Controls

```bash
adb shell tinymix -D 0  # Card 0
adb shell tinymix -D 1  # Card 1
```

### Get/Set a Control

```bash
# Get value
adb shell tinymix "Master Playback Volume"

# Set value
adb shell tinymix "Master Playback Volume" 80

# Mute
adb shell tinymix "Master Playback Switch" 0
```

### HAL Logs

```bash
adb logcat -s AHAL_AlsaMixer:V AHAL_PrimaryMixer:V
```

Logs show:
- Mixer controls found at startup
- setMasterVolume/setMasterMute calls
- Control access errors

### Test via AudioManager

```bash
# Via adb
adb shell media volume --stream 3 --set 10  # Volume to 10/15

# Via Java/Kotlin code
AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
am.setStreamVolume(AudioManager.STREAM_MUSIC, 10, 0);
```

## Current Limitations

1. **Configurable control names**: Control names are now loaded from XML (mixer_controls.xml) with fallback to defaults.

2. **No mixer routing**: The HAL doesn't manage ALSA mixer paths/routing. For that, integrate a mixer paths manager (like audio_route or mixer_paths.xml).

3. **Limited per-channel volume**: The HAL applies the same volume to all channels of a multi-channel control.

4. **No volume curves**: The HAL uses linear conversion (0-100%). For logarithmic curves, modify the conversion methods.

## Possible Improvements

1. **Mixer routing support** via mixer_paths.xml
2. **Custom volume curves** per platform
3. **Support for ALSA enum controls**
4. **Dynamic control discovery** (enumerate all controls at runtime)
5. **Per-stream routing** configuration

## References

- Source code: `alsa/Mixer.cpp`, `primary/PrimaryMixer.cpp`
- Configuration: [CONFIGURATION.md](CONFIGURATION.md)
- TinyAlsa documentation: https://github.com/tinyalsa/tinyalsa
- ALSA mixer API: https://www.alsa-project.org/alsa-doc/alsa-lib/group___mixer.html

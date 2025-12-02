# BayLibre Audio HAL Porting Guide

This guide explains how to port the BayLibre generic audio HAL to a new platform.

## Porting Steps

### 1. Identify Audio Hardware

On your device, identify available audio devices:

```bash
adb shell cat /proc/asound/cards
adb shell cat /proc/asound/devices
adb shell cat /proc/asound/pcm
```

Note the card and device numbers for each audio output/input.

### 2. Create Audio Policy Configuration

Create an `audio_policy_configuration.xml` file for your platform in your device tree:

```
device/yourvendor/yourdevice/audio/audio_policy_configuration.xml
```

Basic structure:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<audioPolicyConfiguration>
    <modules>
        <!-- Primary module for ALSA audio -->
        <module name="primary" halVersion="AIDL">
            <attachedDevices>
                <item>Speaker</item>
                <item>Built-In Mic</item>
            </attachedDevices>
            <devicePorts>
                <!-- Define your audio devices here -->
                <devicePort tagName="Speaker" type="AUDIO_DEVICE_OUT_SPEAKER" role="sink">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_OUT_STEREO"/>
                </devicePort>
                <devicePort tagName="Built-In Mic" type="AUDIO_DEVICE_IN_BUILTIN_MIC" role="source">
                    <profile name="" format="AUDIO_FORMAT_PCM_16_BIT"
                             samplingRates="48000" channelMasks="AUDIO_CHANNEL_IN_STEREO"/>
                </devicePort>
            </devicePorts>
            <!-- Mixer ports (logical connections) -->
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
            <!-- Routes (connections between mixer and devices) -->
            <routes>
                <route type="mix" sink="Speaker" sources="primary output"/>
                <route type="mix" sink="primary input" sources="Built-In Mic"/>
            </routes>
        </module>

        <!-- Optional modules -->
        <!-- USB Audio -->
        <xi:include href="usb_audio_policy_configuration.xml"/>

        <!-- Bluetooth -->
        <xi:include href="bluetooth_audio_policy_configuration.xml"/>

        <!-- Remote Submix (for system capture) -->
        <xi:include href="r_submix_audio_policy_configuration.xml"/>
    </modules>
</audioPolicyConfiguration>
```

### 3. Create Mixer Controls Configuration

Identify your ALSA mixer control names:

```bash
adb shell tinymix -D 0
```

Create `mixer_controls.xml` for your platform:

```bash
mkdir -p device/yourvendor/yourdevice/audio
```

Create the file with your control names:

```xml
<?xml version="1.0" encoding="utf-8"?>
<mixerControls>
    <control function="MASTER_VOLUME" type="int">
        <name>Your Volume Control Name</name>
        <name>Alternate Name If First Not Found</name>
    </control>

    <control function="MASTER_SWITCH" type="bool">
        <name>Your Mute Control Name</name>
    </control>

    <control function="HW_VOLUME" type="int">
        <name>Headphone Playback Volume</name>
        <name>Speaker Playback Volume</name>
    </control>

    <control function="MIC_SWITCH" type="bool">
        <name>Capture Switch</name>
    </control>

    <control function="MIC_GAIN" type="int">
        <name>Capture Volume</name>
    </control>
</mixerControls>
```

See [CONFIGURATION.md](CONFIGURATION.md) for complete XML format documentation.

### 4. Configure device.mk

In your `device.mk`, add:

```make
# Audio HAL
PRODUCT_PACKAGES += \
    com.android.hardware.audio.baylibre

# Audio configuration files
PRODUCT_COPY_FILES += \
    device/yourvendor/yourdevice/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    device/yourvendor/yourdevice/audio/mixer_controls.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration.xml

# Set ALSA card (choose ONE method):
# Method 1: By name (recommended - handles USB devices changing indices)
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.audio.primary.card_name=YOUR_CARD_NAME
# Method 2: By index (fallback if name not set)
# PRODUCT_PROPERTY_OVERRIDES += \
#     persist.vendor.audio.primary.card=0
```

### 5. Test the HAL

After building and flashing:

```bash
# Check that audio service is started
adb shell ps -A | grep audio

# Check loaded configuration
adb shell dumpsys media.audio_policy

# Test audio playback
adb shell tinymix
adb shell tinyplay /system/media/audio/alarms/Argon.ogg
```

## Platform-Specific Adaptations

### Amlogic Platforms

For Amlogic SoCs (S905, S912, G12A, G12B, SM1, etc.):

**Specifics:**
- SPDIF and HDMI audio support
- Audio card names vary by board:
  - Khadas VIM3: `KHADASVIM3`
  - Khadas VIM3L: `G12BKHADASVIM3L`
  - Generic boards: `AMLAUGESOUND` or similar
- Multiple audio devices (I2S, SPDIF, HDMI)
- Limited hardware mixer controls (volume often in software)
- HDMI routing done via TOHDMITX mixer controls

**Card detection by name (recommended for boards with USB devices):**

When USB devices are present (cameras, audio interfaces), they may take card 0 and push the Amlogic audio to a different index. Use card name detection to automatically find the correct card:

```make
# In audio_properties.mk
ifeq ($(TARGET_DEV_BOARD), vim3l)
    AUDIO_CARD_NAME := G12BKHADASVIM3L
else
    AUDIO_CARD_NAME := KHADASVIM3
endif

PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.audio.primary.card_name=$(AUDIO_CARD_NAME)
```

**Example mixer_controls.xml for HDMI output:**
```xml
<mixerControls>
    <control function="MASTER_SWITCH" type="bool">
        <name>TOHDMITX Switch</name>
    </control>

    <!-- Init section for HDMI audio routing -->
    <init>
        <set name="TOHDMITX Switch" value="1"/>
        <set name="TOHDMITX I2S SRC" value="I2S A"/>
        <set name="TDMOUT_A SRC SEL" value="IN 0"/>
        <set name="FRDDR_A SRC 1 EN Switch" value="1"/>
        <set name="FRDDR_A SINK 1 SEL" value="OUT 0"/>
        <set name="TDMOUT_A Lane 0 Volume" value="255,255"/>
        <set name="TDMOUT_A Gain Enable Switch" value="1"/>
    </init>
</mixerControls>
```

### Rockchip Platforms

For Rockchip SoCs (RK3399, RK3588, etc.):

**Specifics:**
- Various audio codecs (ES8316, RT5640, etc.)
- HDMI audio configuration via CEC
- Support for rockchip-sound cards

**Example mixer_controls.xml:**
```xml
<mixerControls>
    <control function="MASTER_VOLUME" type="int">
        <name>Headphone Playback Volume</name>
        <name>DAC Playback Volume</name>
    </control>

    <control function="MIC_GAIN" type="int">
        <name>ADC Capture Volume</name>
        <name>Mic Boost Volume</name>
    </control>
</mixerControls>
```

## Debugging

### Audio Logs

```bash
adb logcat -s AudioHAL:V AHAL_Main:V AHAL_AlsaMixer:V
```

### Debug Properties

```bash
adb shell setprop persist.vendor.audio.hal.debug true
adb shell setprop log.tag.AudioHAL VERBOSE
```

### Check ALSA Devices

```bash
adb shell cat /proc/asound/cards
adb shell cat /proc/asound/pcm
adb shell tinymix -D 0  # List controls for card 0
```

### Verify Configuration

```bash
# Check which mixer controls were found
adb logcat -d | grep "AHAL_AlsaMixer.*available mixer control"

# Check ALSA card/device being used
adb logcat -d | grep "AHAL_PrimaryMixer.*initialized"

# Check system properties
adb shell getprop | grep persist.vendor.audio
```

## Common Issues

### Issue: No audio output

**Cause**: Wrong ALSA card or device selected (often due to USB devices taking card 0)

**Solution 1 - Use card name detection (recommended)**:
```bash
# Find your card name
adb shell cat /proc/asound/cards
# Example output: 1 [G12BKHADASVIM3L]: axg-sound-card - G12B-KHADAS-VIM3L

# Set card name property
adb shell setprop persist.vendor.audio.primary.card_name G12BKHADASVIM3L

# Restart HAL
adb shell stop vendor.audio-hal-aidl
adb shell start vendor.audio-hal-aidl
```

**Solution 2 - Use card index**:
```bash
# Identify correct card
adb shell cat /proc/asound/cards

# Update property
adb shell setprop persist.vendor.audio.primary.card <correct_number>

# Restart HAL
adb shell stop vendor.audio-hal-aidl
adb shell start vendor.audio-hal-aidl
```

### Issue: Volume control not working

**Cause**: Mixer control names don't match your hardware

**Solution**:
1. List available controls: `adb shell tinymix -D 0`
2. Update mixer_controls.xml with correct names
3. Rebuild and reflash
4. Check logs to verify controls were found

### Issue: HAL service crashes

**Cause**: Missing audio_policy_configuration.xml or invalid format

**Solution**:
1. Check file exists: `adb shell ls -l /vendor/etc/audio_policy_configuration.xml`
2. Validate XML syntax
3. Check logcat for error messages: `adb logcat -s AHAL_Main:E`

## See Also

- [CONFIGURATION.md](CONFIGURATION.md) - Complete configuration reference
- [MIXER_CONTROLS.md](MIXER_CONTROLS.md) - Mixer controls implementation details
- [README.md](README.md) - HAL overview and architecture
- AOSP Audio Documentation: https://source.android.com/docs/core/audio
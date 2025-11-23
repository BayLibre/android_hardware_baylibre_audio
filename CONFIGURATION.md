# HAL Audio Configuration Guide

This document explains how to configure the BayLibre Generic Audio HAL for your platform without modifying the source code.

## System Properties Configuration

The HAL supports several system properties for runtime configuration:

### ALSA Card and Device Selection

```bash
# Set the primary ALSA card number (default: 0)
adb shell setprop persist.vendor.audio.primary.card 1

# Set the primary ALSA device number (default: 0)
adb shell setprop persist.vendor.audio.primary.device 0
```

These properties are read once when the HAL service starts. To apply changes:

```bash
adb shell stop vendor.audio-hal-aidl
adb shell start vendor.audio-hal-aidl
```

### Mixer Controls Configuration File

```bash
# Set custom mixer controls XML file location (default: /vendor/etc/mixer_controls.xml)
adb shell setprop persist.vendor.audio.mixer.config /vendor/etc/custom_mixer.xml
```

## Mixer Controls XML Configuration

The HAL loads ALSA mixer control names from an XML configuration file. This allows you to adapt the HAL to different audio drivers without code changes.

### Configuration File Location

Default: `/vendor/etc/mixer_controls.xml`

Override via property: `persist.vendor.audio.mixer.config`

### XML Format

```xml
<?xml version="1.0" encoding="utf-8"?>
<mixerControls>
    <!-- Define each control function -->
    <control function="MASTER_VOLUME" type="int">
        <!-- List possible control names (first found is used) -->
        <name>Master Playback Volume</name>
        <name>Alternate Control Name</name>
    </control>

    <control function="MASTER_SWITCH" type="bool">
        <name>Master Playback Switch</name>
    </control>

    <!-- More controls... -->
</mixerControls>
```

### Supported Functions

- `MASTER_VOLUME` (type: int) - Master volume control
- `MASTER_SWITCH` (type: bool) - Master mute/unmute
- `HW_VOLUME` (type: int) - Per-device hardware volume
- `MIC_SWITCH` (type: bool) - Microphone mute/unmute
- `MIC_GAIN` (type: int) - Microphone gain/volume

### Supported Types

- `int` - Integer control (volume, gain)
- `bool` - Boolean control (switch, mute)

## Platform Configuration Workflow

### 1. Identify your ALSA controls

```bash
adb shell tinymix -D 0
```

This lists all available mixer controls for card 0.

### 2. Create mixer_controls.xml

```bash
mkdir -p device/yourvendor/yourdevice/audio
```

Edit the file with your control names:

```xml
<?xml version="1.0" encoding="utf-8"?>
<mixerControls>
    <control function="MASTER_VOLUME" type="int">
        <name>Your Volume Control Name</name>
    </control>
    <!-- Add your controls... -->
</mixerControls>
```

### 3. Create audio_policy_configuration.xml

Define your audio devices, ports, and routes. See [PORTING.md](PORTING.md) for examples.

### 4. Install in device.mk

```make
# Audio HAL package
PRODUCT_PACKAGES += \
    com.android.hardware.audio.baylibre

# Audio configuration files
PRODUCT_COPY_FILES += \
    device/yourvendor/yourdevice/audio/mixer_controls.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml \
    device/yourvendor/yourdevice/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml

# Set ALSA card if not 0 (optional)
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.audio.primary.card=0
```

## Configuration Examples

### Example 1: Amlogic S905X3

```xml
<mixerControls>
    <control function="MASTER_VOLUME" type="int">
        <name>HDMI Playback Volume</name>
        <name>TOHDMITX Playback Volume</name>
        <name>Master Playback Volume</name>
    </control>

    <control function="MASTER_SWITCH" type="bool">
        <name>TOHDMITX Switch</name>
        <name>HDMI Playback Switch</name>
    </control>

    <control function="HW_VOLUME" type="int">
        <name>LINEOUT volume</name>
        <name>Speaker Playback Volume</name>
    </control>
</mixerControls>
```

### Example 2: Rockchip RK3399 with ES8316 codec

```xml
<mixerControls>
    <control function="MASTER_VOLUME" type="int">
        <name>Headphone Playback Volume</name>
        <name>DAC Playback Volume</name>
    </control>

    <control function="HW_VOLUME" type="int">
        <name>HP Playback Volume</name>
        <name>SPK Playback Volume</name>
    </control>

    <control function="MIC_GAIN" type="int">
        <name>ADC Capture Volume</name>
        <name>Mic Boost Volume</name>
    </control>
</mixerControls>
```

### Example 3: Generic Platform

If you're unsure about your control names, use the default configuration from `mixer_controls.xml` at the root of this directory. The HAL will try standard names first.

## Fallback Behavior

If the mixer_controls.xml file is not found or cannot be parsed, the HAL will use built-in default control names:

- Master Playback Volume
- Master Playback Switch
- Headphone/Headset/PCM Playback Volume
- Capture Switch
- Capture Volume

## Debugging Configuration

### Check which controls are loaded

```bash
adb logcat -s AHAL_AlsaMixer:D | grep "available mixer control"
```

Example output:
```
AHAL_AlsaMixer: available mixer control names=[Master Playback Volume,Capture Switch]
```

### Test mixer control changes

```bash
# Read current value
adb shell tinymix "Master Playback Volume"

# Set value
adb shell tinymix "Master Playback Volume" 80

# Test from Android
adb shell media volume --stream 3 --set 10
```

### Verify property values

```bash
adb shell getprop persist.vendor.audio.primary.card
adb shell getprop persist.vendor.audio.mixer.config
```

## Common Issues

### Issue: "Failed to open mixer for card=X"

**Solution:** Check that the ALSA card exists:
```bash
adb shell cat /proc/asound/cards
adb shell cat /proc/asound/devices
```

Set the correct card number:
```bash
adb shell setprop persist.vendor.audio.primary.card <correct_number>
adb shell stop vendor.audio-hal-aidl
adb shell start vendor.audio-hal-aidl
```

### Issue: Volume control not working

**Solution:**
1. List available controls: `adb shell tinymix -D 0`
2. Update mixer_controls.xml with the correct control names
3. Rebuild and reflash, or push the file and restart HAL
4. Check logs: `adb logcat -s AHAL_AlsaMixer:V`

### Issue: "No controls loaded from XML, using defaults"

**Solution:**
1. Check file exists: `adb shell ls -l /vendor/etc/mixer_controls.xml`
2. Check XML syntax is valid
3. Check file permissions (should be readable by audioserver)
4. Check logs for XML parsing errors

## Best Practices

1. **Start with the default config** - Use the `mixer_controls.xml` in this directory as a base
2. **Test incrementally** - Add one control at a time and test
3. **Use multiple names** - List multiple possible control names for better compatibility
4. **Check logs** - Always verify which controls were found in logcat
5. **Document your config** - Add comments in your XML for future reference

## Advanced Configuration

### Per-device configurations

You can have different configurations for different device variants:

```make
# In your device.mk
ifeq ($(TARGET_PRODUCT),mydevice_hdmi)
    PRODUCT_COPY_FILES += \
        device/myvendor/mydevice/audio/mixer_controls_hdmi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml
else
    PRODUCT_COPY_FILES += \
        device/myvendor/mydevice/audio/mixer_controls_default.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml
endif
```

### Runtime configuration switching

You can switch configurations at runtime (useful for development/testing):

```bash
# Copy alternate config to device
adb push my_alternate_config.xml /vendor/etc/mixer_controls_alt.xml

# Switch to it
adb shell setprop persist.vendor.audio.mixer.config /vendor/etc/mixer_controls_alt.xml

# Restart HAL to apply
adb shell stop vendor.audio-hal-aidl
adb shell start vendor.audio-hal-aidl
```

### Conditional properties

You can set properties conditionally based on product variant:

```make
# In device.mk
ifeq ($(TARGET_BOARD_PLATFORM),amlogic)
    PRODUCT_PROPERTY_OVERRIDES += \
        persist.vendor.audio.primary.card=0
else ifeq ($(TARGET_BOARD_PLATFORM),rockchip)
    PRODUCT_PROPERTY_OVERRIDES += \
        persist.vendor.audio.primary.card=1
endif
```

## See Also

- [PORTING.md](PORTING.md) - General porting guide
- [MIXER_CONTROLS.md](MIXER_CONTROLS.md) - Mixer controls implementation details
- [README.md](README.md) - HAL overview and architecture
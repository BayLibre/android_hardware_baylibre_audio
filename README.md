# BayLibre Generic Audio HAL (AIDL)

## Description

This generic AIDL audio HAL is designed to be easily adaptable to different platforms (Amlogic, Rockchip, etc.). It is based on the AOSP reference implementation and has been modified to offer more flexibility.

## Architecture

The HAL supports multiple audio modules:

- **Primary/ALSA**: Main module using ALSA for basic audio
- **USB**: USB audio device support
- **Bluetooth**: Bluetooth headset and speaker support
- **R_submix**: System audio capture (remote submix)
- **Stub**: Test/development module

## Multi-platform Usage

### Platform Configuration

To adapt this HAL to your specific platform:

1. **Audio policy configuration**:
   - Create audio_policy_configuration.xml according to your hardware
   - Define your audio devices, ports, and routes

2. **ALSA configuration**:
   - Configure ALSA card and device numbers via system properties
   - Create mixer_controls.xml with your ALSA mixer control names

3. **Optional modules**:
   - Enable/disable modules in the VINTF manifest as needed
   - Comment out unused modules in android.hardware.audio.service-aidl.baylibre.xml

### System Properties

The HAL can be configured via system properties:

```bash
# ALSA card and device selection
persist.vendor.audio.primary.card=0
persist.vendor.audio.primary.device=0

# Mixer controls configuration file
persist.vendor.audio.mixer.config=/vendor/etc/mixer_controls.xml
```

### Build for a Specific Platform

In your platform's `device.mk`:

```make
# Include BayLibre Audio HAL
PRODUCT_PACKAGES += \
    com.android.hardware.audio.baylibre

# Copy platform-specific mixer controls configuration
PRODUCT_COPY_FILES += \
    device/yourvendor/yourdevice/audio/mixer_controls.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_controls.xml

# Set system properties
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.audio.primary.card=0
```

## File Structure

- `main.cpp`: Audio service entry point
- `Module.cpp`: Main audio module implementation
- `alsa/`: Generic ALSA implementation
- `bluetooth/`: Bluetooth support
- `usb/`: USB audio support
- `primary/`: Primary audio module
- `r_submix/`: Remote submix
- `stub/`: Stub module for testing
- `config/`: XML configuration files
- `*Effect*/`: Audio effect implementations

## Adaptation to a New Platform

1. Create an audio policy configuration XML for your platform
2. Create a mixer_controls.xml with your ALSA control names
3. Set system properties for ALSA card/device if not 0
4. Build the HAL with your configuration
5. Test with `adb shell dumpsys media.audio_policy`

## Configuration

See [CONFIGURATION.md](CONFIGURATION.md) for detailed configuration instructions.

## Porting Guide

See [PORTING.md](PORTING.md) for step-by-step platform porting instructions.

## Mixer Controls

See [MIXER_CONTROLS.md](MIXER_CONTROLS.md) for details on ALSA mixer control management.

## Support

For questions or contributions, contact the BayLibre team.
# Generic Audio HAL Properties
# These properties can be customized per platform

# Primary audio device (ALSA card number)
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.primary.card=0 \\
    persist.vendor.audio.primary.device=0

# Enable/disable audio modules
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.usb.enabled=true \\
    persist.vendor.audio.bluetooth.enabled=true \\
    persist.vendor.audio.rsubmix.enabled=true

# Audio output routing
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.speaker.device=0 \\
    ro.vendor.audio.headset.device=1

# Audio input routing
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.mic.device=0

# Buffer sizes and latency
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.period_size=192 \\
    ro.vendor.audio.period_count=4

# Sample rates
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.default.sample_rate=48000

# Debug
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.hal.debug=false

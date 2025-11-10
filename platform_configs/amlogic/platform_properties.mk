# Amlogic Platform Audio HAL Properties
# Configuration optimisée pour les SoCs Amlogic

# Primary audio device (Amlogic audio card)
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.primary.card=0 \\
    persist.vendor.audio.primary.device=0

# Enable/disable audio modules
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.usb.enabled=true \\
    persist.vendor.audio.bluetooth.enabled=true \\
    persist.vendor.audio.rsubmix.enabled=true

# Amlogic specific routing
# Les SoCs Amlogic ont généralement :
# - Device 0 : I2S output (speakers)
# - Device 1 : SPDIF output
# - Device 2 : HDMI audio
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.speaker.device=0 \\
    ro.vendor.audio.spdif.device=1 \\
    ro.vendor.audio.hdmi.device=2

# Audio input
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.mic.device=0

# Buffer sizes optimisés pour Amlogic
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.period_size=256 \\
    ro.vendor.audio.period_count=4

# Sample rates supportés
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.default.sample_rate=48000 \\
    ro.vendor.audio.hdmi.sample_rates=48000,96000,192000

# Amlogic specific features
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.spdif.enabled=true \\
    ro.vendor.audio.hdmi.passthrough=true

# Debug
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.hal.debug=false

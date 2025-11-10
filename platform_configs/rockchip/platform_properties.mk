# Rockchip Platform Audio HAL Properties
# Configuration optimisée pour les SoCs Rockchip

# Primary audio device (Rockchip audio card)
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.primary.card=0 \\
    persist.vendor.audio.primary.device=0

# Enable/disable audio modules
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.usb.enabled=true \\
    persist.vendor.audio.bluetooth.enabled=true \\
    persist.vendor.audio.rsubmix.enabled=true

# Rockchip specific routing
# Les SoCs Rockchip ont généralement :
# - Device 0 : I2S output (speakers/headphone)
# - Device 1 : HDMI audio
# - Device 2 : SPDIF output (selon le modèle)
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.speaker.device=0 \\
    ro.vendor.audio.hdmi.device=1 \\
    ro.vendor.audio.headset.device=0

# Audio input
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.mic.device=0 \\
    ro.vendor.audio.mic.channels=2

# Buffer sizes optimisés pour Rockchip
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.period_size=192 \\
    ro.vendor.audio.period_count=4

# Sample rates supportés
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.default.sample_rate=48000 \\
    ro.vendor.audio.hdmi.sample_rates=48000,96000

# Rockchip specific features
PRODUCT_PROPERTY_OVERRIDES += \\
    ro.vendor.audio.codec.es8316=false \\
    ro.vendor.audio.codec.rt5640=false

# Debug
PRODUCT_PROPERTY_OVERRIDES += \\
    persist.vendor.audio.hal.debug=false

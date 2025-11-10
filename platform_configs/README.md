# Configurations par plateforme

Ce répertoire contient des exemples de configurations pour différentes plateformes.

## Structure

- `amlogic/` : Configuration pour les SoCs Amlogic
- `rockchip/` : Configuration pour les SoCs Rockchip
- `generic/` : Configuration générique de référence

## Utilisation

1. Copiez les fichiers de configuration de votre plateforme dans votre device tree
2. Adaptez les paramètres selon votre hardware spécifique
3. Référencez ces fichiers dans votre `device.mk`

## Fichiers de configuration typiques

- `audio_policy_configuration.xml` : Configuration des ports, devices et routes audio
- `audio_effects.xml` : Configuration des effets audio
- `mixer_paths.xml` : Configuration des chemins mixer ALSA (si applicable)
- `platform_properties.mk` : Propriétés système pour le HAL

## Customisation

Pour créer une configuration pour une nouvelle plateforme :

1. Partez de la configuration `generic/` comme base
2. Identifiez vos périphériques audio ALSA (`adb shell cat /proc/asound/cards`)
3. Adaptez les numéros de cartes et périphériques dans la configuration
4. Testez et ajustez selon les besoins

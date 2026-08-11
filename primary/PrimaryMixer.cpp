/*
 * Copyright (C) 2023 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "AHAL_PrimaryMixer"

#include <fstream>
#include <regex>

#include <Log.h>
#include <android-base/properties.h>

#include "PrimaryMixer.h"

namespace aidl::android::hardware::audio::core::primary {

// static
int PrimaryMixer::findAlsaCardByName(const std::string& cardName) {
    std::ifstream cardsFile("/proc/asound/cards");
    if (!cardsFile.is_open()) {
        LOG(WARNING) << __func__ << ": Cannot open /proc/asound/cards";
        return kInvalidAlsaCard;
    }

    // Card lines look like: " 0 [AMLAUGESOUND   ]: driver - longname"
    static const std::regex kCardRegex(R"(^\s*(\d+)\s+\[([^\]]+)\])");
    std::string line;
    while (std::getline(cardsFile, line)) {
        std::smatch match;
        if (!std::regex_search(line, match, kCardRegex)) continue;

        const int cardNum = std::stoi(match[1].str());
        std::string name = match[2].str();
        name.erase(name.find_last_not_of(" \t") + 1);
        LOG(DEBUG) << __func__ << ": Found card " << cardNum << " name='" << name << "'";
        if (name.find(cardName) != std::string::npos) {
            LOG(INFO) << __func__ << ": Matched card " << cardNum << " for requested name '"
                      << cardName << "'";
            return cardNum;
        }
    }

    LOG(WARNING) << __func__ << ": Card with name '" << cardName << "' not found";
    return kInvalidAlsaCard;
}

// static
int PrimaryMixer::getAlsaCard() {
    // A card name takes precedence over a card index: USB devices such as cameras
    // may claim card 0 and push the primary card to a non-deterministic index.
    const std::string cardName = ::android::base::GetProperty(
            "persist.vendor.audio.primary.card_name",
            ::android::base::GetProperty("ro.vendor.audio.primary.card_name", ""));
    if (!cardName.empty()) {
        const int card = findAlsaCardByName(cardName);
        if (card != kInvalidAlsaCard) {
            LOG(INFO) << __func__ << ": Using ALSA card " << card << " (found by name '" << cardName
                      << "')";
            return card;
        }
        LOG(WARNING) << __func__ << ": Card name '" << cardName
                     << "' not found, falling back to card index";
    }

    const int card = ::android::base::GetIntProperty(
            "persist.vendor.audio.primary.card",
            ::android::base::GetIntProperty("ro.vendor.audio.primary.card", kDefaultAlsaCard));
    LOG(DEBUG) << __func__ << ": Using ALSA card " << card;
    return card;
}

// static
int PrimaryMixer::getAlsaDevice() {
    const int device = ::android::base::GetIntProperty(
            "persist.vendor.audio.primary.device",
            ::android::base::GetIntProperty("ro.vendor.audio.primary.device", kDefaultAlsaDevice));
    LOG(DEBUG) << __func__ << ": Using ALSA device " << device;
    return device;
}

PrimaryMixer::PrimaryMixer() : alsa::Mixer(getAlsaCard()) {
    LOG(INFO) << "PrimaryMixer initialized with card=" << getAlsaCard()
              << " device=" << getAlsaDevice();
}

// static
PrimaryMixer& PrimaryMixer::getInstance() {
    static PrimaryMixer gInstance;
    return gInstance;
}

}  // namespace aidl::android::hardware::audio::core::primary

import 'package:chitchat/global_data.dart';
import 'package:flutter/material.dart';
import 'package:chitchat/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const SettingsScreen({Key? key, required this.prefs}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _promptStringController;
  late TextEditingController _temperatureValueController;
  late TextEditingController
      _proxyUrlController; // new controller for proxy URL
  late TextEditingController _baseUrlController; //
  late bool _continueConversationEnable;
  late bool _localCacheEnable;
  late bool _ttsEnable;

  late String? _ttsSelectedLanguage;
  late LocaleName? _sttSelectedLanguage;
  late AppLocalizations loc;

  @override
  void initState() {
    super.initState();



    // If the temperature value has not been set, set it to 1.0
    if (widget.prefs.getDouble(Constants.temperatureValueKey) == 0.0) {
      widget.prefs.setDouble(Constants.temperatureValueKey, 1.0);
    }

    _apiKeyController = TextEditingController(
        text: widget.prefs.getString(Constants.apiKeyKey));
    _promptStringController = TextEditingController(
        text: widget.prefs.getString(Constants.promptStringKey));
    _temperatureValueController = TextEditingController(
      text: widget.prefs.getDouble(Constants.temperatureValueKey) == null
          ? "1.0"
          : widget.prefs.getDouble(Constants.temperatureValueKey).toString(),
    );
    _continueConversationEnable =
        widget.prefs.getBool(Constants.continueConversationEnableKey) ??
            Constants.defaultContinueConversationEnable;
    _localCacheEnable = widget.prefs.getBool(Constants.localCacheEnableKey) ??
        Constants.defaultLocalCacheEnable;
    _ttsEnable = widget.prefs.getBool(Constants.ttsEnableKey) ??
        Constants.defaultTtsEnable;

    _proxyUrlController = TextEditingController(
        text: widget.prefs.getString(Constants.proxyUrlKey));

    _baseUrlController = TextEditingController(
        text: widget.prefs.getString(Constants.baseUrlKey));

    setState(() {
      _ttsSelectedLanguage =
          widget.prefs.getString(Constants.ttsSelectedLanguageKey);

      if (GlobalData().sttLocaleNames.isNotEmpty) {
        String? savedSttSelectedLanguage =
            widget.prefs.getString(Constants.sttSelectedLanguageKey);
        _sttSelectedLanguage = GlobalData().sttLocaleNames.firstWhere(
              (element) => savedSttSelectedLanguage == element.localeId,
              orElse: () =>
                  GlobalData().sttLocaleNames[0], // Set a default value
            );

        // print("selected: " + _sttSelectedLanguage!.localeId);
      }
    });
  }

  void _saveSettings() {
    widget.prefs.setString(Constants.apiKeyKey, _apiKeyController.text);
    widget.prefs
        .setString(Constants.promptStringKey, _promptStringController.text);
    widget.prefs.setDouble(Constants.temperatureValueKey,
        double.parse(_temperatureValueController.text));
    widget.prefs.setBool(
        Constants.continueConversationEnableKey, _continueConversationEnable);
    widget.prefs.setBool(Constants.localCacheEnableKey, _localCacheEnable);
    widget.prefs.setBool(Constants.ttsEnableKey, _ttsEnable);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.settings_saved),
      ),
    );
    widget.prefs.setString(Constants.proxyUrlKey, _proxyUrlController.text);
    widget.prefs.setString(Constants.baseUrlKey, _baseUrlController.text);

    widget.prefs.setString(
        Constants.ttsSelectedLanguageKey, _ttsSelectedLanguage ?? "");

    if (null != _sttSelectedLanguage) {
      widget.prefs.setString(
          Constants.sttSelectedLanguageKey, _sttSelectedLanguage!.name);
    }

    Navigator.pop(context);
  }

  void _clearChatHistory() {
    // Clear the chat history from the shared preferences
    widget.prefs.remove(Constants.cacheHistoryKey);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.conversationRecordsErased),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enable = true,
  }) {
    return TextFormField(
      enabled: enable,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    loc = AppLocalizations.of(context); // Add this line
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _apiKeyController,
                label: loc.openAIApiKey,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                enable: false,
                controller: _promptStringController,
                label: loc.promptString,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _temperatureValueController,
                label: loc.temperatureValue,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(loc.continueConversation),
                value: _continueConversationEnable,
                onChanged: (value) {
                  setState(() {
                    _continueConversationEnable = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: Text(loc.localCache),
                value: _localCacheEnable,
                onChanged: (value) {
                  setState(() {
                    _localCacheEnable = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: Text(loc.enableTts),
                value: _ttsEnable,
                onChanged: (value) {
                  setState(() {
                    _ttsEnable = value!;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.ttsLanguage),
                          _buildTtsLanguageDropdown(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.sttLanguage),
                          _buildSttLanguageDropdown(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _clearChatHistory,
                child: Text(loc.clearChatHistory),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _proxyUrlController, // add text field for proxy URL
                label: loc.proxyUrl,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _baseUrlController, // add text field for proxy URL
                label: loc.openAIBaseUrl,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text(loc.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTtsLanguageDropdown() {
    if (GlobalData().ttsLanguages.isEmpty) {
      return Text(loc.noTtsLanguagesAvailable);
    }

    return DropdownButton<String>(
      value: _ttsSelectedLanguage ?? GlobalData().ttsLanguages[0],
      items: GlobalData().ttsLanguages.toSet().map((dynamic value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _ttsSelectedLanguage = newValue!;
          widget.prefs.setString(
              Constants.ttsSelectedLanguageKey, _ttsSelectedLanguage ?? "");
        });
      },
    );
  }

  Widget _buildSttLanguageDropdown() {
    if (GlobalData().sttLocaleNames.isEmpty) {
      return Text(loc.noSttLanguagesAvailable);
    }

    return DropdownButton<LocaleName>(
      value: _sttSelectedLanguage ?? GlobalData().sttLocaleNames[0],
      items: GlobalData().sttLocaleNames.toSet().map((LocaleName value) {
        return DropdownMenuItem<LocaleName>(
          value: value,
          child: Text(value.name),
        );
      }).toList(),
      onChanged: (LocaleName? newValue) {
        setState(() {
          _sttSelectedLanguage = newValue!;
          print("selected: " + _sttSelectedLanguage!.localeId);

          if (null != _sttSelectedLanguage) {
            widget.prefs.setString(Constants.sttSelectedLanguageKey,
                _sttSelectedLanguage!.localeId);
          }
        });
      },
    );
  }
}

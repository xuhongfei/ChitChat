import 'dart:async';

import 'package:chitchat/LogUtils.dart';
import 'package:chitchat/models/prompt.dart';
import 'package:chitchat/screens/SyntaxHighlight.dart';
import 'package:chitchat/screens/prompt_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:chitchat/settings.dart';
import 'package:chitchat/constants.dart';
import 'package:chitchat/models/chat_message.dart';
import 'package:chitchat/services/chat_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:about/about.dart';
import 'package:chitchat/pubspec.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key, Settings? settings}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> implements IChatService {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  ChatService? _chatService;
  Settings? _settings;
  ChatHistory? _history;
  final String defaultAppTitle = "ChitChat";
  String appTitle = "";
  late Prompt currentPrompt;
  late PromptStorage promptStorage;
  final _chatListController = ScrollController();

  final FlutterTts flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isSpeechToTextAvailable = false;
  String _lastRecognizedWords = "";
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];

  StreamSubscription? _streamSubscription;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();

  @override
  void initState() {
    super.initState();
    LogUtils.info("init state");
    appTitle = defaultAppTitle;

    _streamSubscription = _messageController.stream.listen((data) {
      setState(() {
        // LogUtils.info("recv: ${_isLoading}, ${data.content}");
        //save to chat history
        if (data.isStop) {
          _history?.addMessageWithPromptChannel(
              _messages.elementAt(_messages.length - 2), currentPrompt.id);
          _history?.addMessageWithPromptChannel(
              _messages.last, currentPrompt.id);
          _speak(_messages.last.content);
        } else {
          _messages.last.content += data.content;
          _listViewScrollToBottom();
        }
      });
    });

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _settings = Settings(prefs: prefs);
        _chatService = ChatService(_settings!.openaiApiKey, _messageController);
        _history = ChatHistory(prefs: prefs);
        // _messages.addAll(_history!.messages);
        promptStorage = PromptStorage(prefs: prefs);
        currentPrompt = promptStorage.getSelectedPrompt();
        _switchToPromptChannel(currentPrompt);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _listViewScrollToBottom();
        });
      });
    });

    _initializeSpeechRecognition();
  }

  Future<void> _initializeSpeechRecognition() async {
    bool available = await _speechToText.initialize(
      onError: (SpeechRecognitionError error) {
        print("Error: ${error.errorMsg}");
        setState(() {
          _isListening = false;
        });
        showToast(error.errorMsg);
      },
      onStatus: (String status) {
        print("Status: $status");

        if (status == "avalilable") {
          //   print("Speech recognition available ${_isSpeechToTextAvailable}");
          //
          //   if (_isSpeechToTextAvailable) {
          //     // Get the list of languages installed on the supporting platform so they
          //     // can be displayed in the UI for selection by the user.
          //     _localeNames = _speechToText.locales();
          //     print(_localeNames);
          //
          //     var systemLocale = _speechToText.systemLocale();
          //     _currentLocaleId = systemLocale?.localeId ?? '';
          //   }
          //
          setState(() {
            _isSpeechToTextAvailable = true;
          });
        }
      },
    );

    print("Speech recognition available ${_isSpeechToTextAvailable}");
    _localeNames = await _speechToText.locales();
    print(_localeNames);

    var systemLocale = await _speechToText.systemLocale();
    _currentLocaleId = systemLocale?.localeId ?? '';
    print(_currentLocaleId);

    if (_isSpeechToTextAvailable) {
      // Get the list of languages installed on the supporting platform so they
      // can be displayed in the UI for selection by the user.
      _localeNames = await _speechToText.locales();
      print(_localeNames);

      var systemLocale = await _speechToText.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';
    }

    setState(() {
      _isSpeechToTextAvailable = available;
    });

    List<dynamic> languages = await flutterTts.getLanguages;
    print(languages);
    // [nn, bg, kea, mg, mr, zu, ko, hsb, ak, kde, lv, seh, dz, mgo, ia, kkj, sd-Arab, pa-Guru, mer, pcm, sah, mni, br, sk, ml, ast, yue-Hans, cs, sv, el, pa, rn, rwk, tg, hu, ks-Arab, af, twq, bm, smn, dsb, sd-Deva, khq, ku, tr, cgg, ksf, cy, yi, fr, sq, de, agq, sa, ebu, zh-Hans, lg, sat-Olck, ff, mn, sd, teo, eu, wo, shi-Tfng, xog, so, ru, az, su-Latn, fa, kab, ms, nus, nd, ug, kk, az-Cyrl, hi, tk, hy, shi-Latn, vai, vi, dyo, mi, mt, ksb, lb, luo, mni-Beng, yav, ne, eo, kam, su, ro, ee, pl, my, ka, ur, mgh, shi, uz-Arab, kl, se, chr, doi, zh, yue-Hant, saq, az-Latn, ta, lag, luy, bo, as, bez, it, kln, uk, kw, mai, vai-Latn, mzn, ii, tt, ksh, ln, naq, pt, tzm, gl, sr-Cyrl, ff-Adlm, fur, om, to, ga, qu, et, asa, mua, jv, id, ps, sn, rof, ff-Latn, km, zgh, be, fil, gv, uz-Cyrl, dua, es, jgo, fo, gsw, hr, lt, guz, mfe, ccp, ja, lkt, ceb, is, or, si, brx, en, ca, te, ks, ha, sl, sbp, nyn, jmc, yue, fi, mk, sat, bs-Cyrl, uz, pa-Arab, sr-Latn, bs, sw, fy, nmg, rm, th, bn, ar, vai-Vaii, haw, kn, dje, bas, nnh, sg, uz-La
    await flutterTts.isLanguageAvailable("en-US")
        ? flutterTts.setLanguage("en-US")
        : flutterTts.setLanguage("en");
    // await flutterTts.setSpeechRate(0.5);
    // await flutterTts.setVolume(1.0);
    // await flutterTts.setPitch(1.0);
  }

  void showToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(milliseconds: 1000),
      ),
    );
  }

  void _toggleListening() async {
    if (_isListening) {
      _speechToText.stop();
      _controller.clear();
      _sendMessage(_lastRecognizedWords);
      setState(() {
        _isListening = false;
      });
    } else {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _lastRecognizedWords = result.recognizedWords;
          });
        },
      );

      setState(() {
        _isListening = true;
      });
    }
  }

  void _speak(String text) async {
    if(false == _settings?.ttsEnable) return;

    print("speak start");
    await flutterTts.speak(text);
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscription?.cancel();
    _messageController?.close();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    LogUtils.info("didChangeDependencies");
  }

  Future<String> _callAPI(
    String content,
  ) async {
    final completion = await _chatService!.getCompletion(
      content,
      _get5ChatHistory(),
      _settings,
      promptStorage,
    );

    return completion;
  }

  @override
  Future<String> translate(String content, String translationPrompt) async {
    setState(() {
      _isLoading = true;
    });
    final completion = await _chatService!.getTranslation(
      content,
      translationPrompt,
      _settings,
    );

    setState(() {
      _isLoading = false;
    });

    return completion;
  }

  void delete(ChatMessage message) {
    setState(() {
      _messages.remove(message);
      _history?.deleteMessageWithPromptChannel(message, currentPrompt.id);
    });
  }

  void _sendMessage(String text) async {
    if (_settings!.openaiApiKey.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('OpenAI API key not set'),
          content: Text('Kindly configure the OpenAI API key in the settings'),
          actions: [
            TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                }),
          ],
        ),
      );
      return;
    }

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _listViewScrollToBottom();

    final messageSend = ChatMessage(role: ChatMessage.ROLE_USER, content: text);
    _messages.add(messageSend);
    _controller.clear();

    if (Constants.useStream) {
      //add as a placeholder for the stream message.
      final messageSend =
          ChatMessage(role: ChatMessage.ROLE_ASSISTANT, content: "");
      _messages.add(messageSend);
    }

    try {
      final completion = await _callAPI(messageSend.content);

      setState(() {
        _isLoading = false;
        final messageReceived =
            ChatMessage(role: ChatMessage.ROLE_ASSISTANT, content: completion);
        if (!Constants.useStream) {
          _messages.add(messageReceived);
          _history?.addMessageWithPromptChannel(messageSend, currentPrompt.id);
          _history?.addMessageWithPromptChannel(
              messageReceived, currentPrompt.id);
        }
      });

      _listViewScrollToBottom();
    } catch (e) {
      LogUtils.error(e.toString());
      if (Constants.useStream) {
        _messages.removeLast();
      }
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to send message'),
      //   ),
      // );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Failed to send message'),
            TextButton(
              child: Text('Retry'),
              onPressed: () => _sendMessage(messageSend.content),
            ),
          ],
        ),
      ));
    }
  }

  List<ChatMessage>? _get5ChatHistory() {
    final recentHistory = _history?.getLatestMessages(currentPrompt.id);
    LogUtils.info("recentHistory length: ${recentHistory}");

    return _settings!.continueConversationEnable ? recentHistory : [];
  }

  void _showAbout() {
    showAboutPage(
      context: context,
      values: {
        'version': Pubspec.version,
        'year': DateTime.now().year.toString(),
      },
      applicationLegalese:
          'Copyright © ${Pubspec.authorsName.join(', ')}, {{ year }}',
      applicationDescription: Text(Pubspec.description),
      children: const <Widget>[
        MarkdownPageListTile(
          icon: Icon(Icons.list),
          title: Text('Changelog'),
          filename: 'assets/CHANGELOG.md',
        ),
        LicensesPageListTile(
          icon: Icon(Icons.favorite),
        ),
      ],
      applicationIcon: const SizedBox(
        width: 100,
        height: 100,
        child: Image(
          image: AssetImage(
              'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'),
        ),
      ),
    );
  }

  // Add a new method to switch to a selected prompt channel.
  void _switchToPromptChannel(Prompt promptChannel) {
    currentPrompt = promptChannel;
    setState(() {
      appTitle = defaultAppTitle + "(${currentPrompt.title})";
      _messages.clear();
      _messages.addAll(_history!.getMessagesForPromptChannel(currentPrompt.id));
      _listViewScrollToBottom();
      LogUtils.info("history size: ${_messages.length}");
      LogUtils.info("currentPrompt: ${currentPrompt}");
    });
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: message.isUser ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.list),
            onPressed: () async {
              final selectedPrompt = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PromptListScreen(
                    onSelectedPrompt: (prompt) {
                      if (prompt != null) {
                        // Switch chat channel based on selected prompt
                        LogUtils.info("selected: ${prompt}");
                        setState(() {
                          _switchToPromptChannel(prompt);
                        });
                      }
                    },
                    promptStorage: promptStorage,
                  ),
                ),
              );
            },
          ),
          title: Text('${appTitle}'),
          actions: [
            IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                }),
            IconButton(
                icon: Icon(Icons.info),
                onPressed: () {
                  _showAbout();
                }),
            IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _history?.deleteMessageForPromptChannel(currentPrompt.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Conversation records erased'),
                      ),
                    );
                  });
                }),
          ],
        ),
        body: SafeArea(
          child: KeyboardVisibilityBuilder(
            builder: (context, isKeyboardVisible) {
              if (isKeyboardVisible) {
                _listViewScrollToBottom();
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding:
                          EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
                      // separatorBuilder: (BuildContext context, int index) =>
                      //     Divider(thickness: 1.0,color: Colors.blueAccent ,),
                      controller: _chatListController,
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ChatMessage message = _messages[index];
                        return ChatMessageWidgetMarkdown(
                          message: message,
                          chatService: this,
                        );
                      },
                    ),
                  ),
                  BottomAppBar(
                    child: Container(
                      // height: 60,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: 'Type a message',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                              ),
                              keyboardType: TextInputType.multiline,
                              maxLines: 10,
                              minLines: 1,
                              // Allows for multiline input
                              textInputAction: TextInputAction.newline,
                              // Allows for newline on "Enter"
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  _sendMessage(value);
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          IconButton(
                            icon: Icon(Icons.send,
                                color: _isLoading ? Colors.grey : null),
                            onPressed: () => _isLoading
                                ? null
                                : _sendMessage(_controller.text),
                          ),
                          if (_isSpeechToTextAvailable)
                            IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic_off : Icons.mic,
                              ),
                              onPressed: _toggleListening,
                            ),
                          if (_isLoading)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void showMessageActions(BuildContext context, ChatMessage message) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.content_copy),
                title: Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied to clipboard'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Share'),
                onTap: () {
                  Share.share(message.content);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.translate),
                title: Text('Translation'),
                onTap: () {
                  translate(message.content, Constants.translationPrompt)
                      .then((translatedText) {
                    setState(() {
                      _messages.add(ChatMessage(
                          role: ChatMessage.ROLE_ASSISTANT,
                          content: translatedText));
                    });
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.book),
                title: Text('Rephrase'),
                onTap: () {
                  translate(message.content, Constants.rephrasePrompt)
                      .then((translatedText) {
                    setState(() {
                      _messages.add(ChatMessage(
                          role: ChatMessage.ROLE_ASSISTANT,
                          content: translatedText));
                    });
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.remove),
                title: Text('Delete'),
                onTap: () {
                  delete(message);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Message deleted'),
                  ));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _listViewScrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _chatListController.animateTo(
        _chatListController.position.maxScrollExtent,
        duration: Duration(milliseconds: Constants.scrollDuration),
        curve: Curves.easeOutSine,
      );
    });
  }
}

class ChatMessageWidgetSimple extends StatelessWidget {
  final ChatMessage message;
  final IChatService chatService;

  const ChatMessageWidgetSimple(
      {required this.message, required this.chatService});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        message.content.replaceAll("\n\n", "\n"),
        textAlign: message.isUser ? TextAlign.right : TextAlign.left,
        // onSelectionChanged: (text, _) {
        //   _showMessageActions(
        //       context, ChatMessage(role: "user", content: text.toString()));
        // },
      ),
      onTap: () => chatService.showMessageActions(context, message),
      tileColor: message.isUser ? Colors.blue[100] : Colors.grey[200],
    );
  }
}

class ChatMessageWidgetMarkdown extends StatelessWidget {
  final ChatMessage message;
  final IChatService chatService;

  const ChatMessageWidgetMarkdown(
      {required this.message, required this.chatService});

  @override
  Widget build(BuildContext context) {
    ThemeData themeData = Theme.of(context);
    MarkdownStyleSheet markdownStyleSheet =
        MarkdownStyleSheet.fromTheme(themeData);
    // markdownStyleSheet.textAlign = message.isUser ?  WrapAlignment.end : WrapAlignment.start;
    return ListTile(
      title: MarkdownBody(
        key: const Key("defaultmarkdownformatter"),
        data: message.content,
        styleSheetTheme: MarkdownStyleSheetBaseTheme.platform,

        // builders: {
        //   'code': CodeElementBuilder(),
        // },
      ),
      tileColor: message.isUser ? Colors.blue[100] : Colors.grey[200],
      onTap: () => chatService.showMessageActions(context, message),
      // contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );
  }
}

abstract class IChatService {
  Future<String> translate(String content, String translationPrompt);

  void showMessageActions(BuildContext context, ChatMessage message);
}

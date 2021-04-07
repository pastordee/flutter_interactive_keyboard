import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_interactive_keyboard/src/channel_receiver.dart';
import 'channel_manager.dart';

class KeyboardManagerWidget extends StatefulWidget {

  /// The widget behind the view where the drag to close is enabled
  final Widget child;

  final Function? onKeyboardOpen;
  final Function? onKeyboardClose;
  
  KeyboardManagerWidget(
      {Key? key, required this.child, this.onKeyboardOpen, this.onKeyboardClose})
      : super(key: key);

  KeyboardManagerWidgetState createState() => KeyboardManagerWidgetState();
}

class KeyboardManagerWidgetState extends State<KeyboardManagerWidget> {
  late ChannelReceiver _channelReceiver;

  List<int> _pointers = [];
  int? get activePointer => _pointers.length > 0 ? _pointers.first : null;

  List<double> _velocities = [];
  double _velocity = 0.0;
  int _lastTime = 0;
  double _lastPosition = 0.0;

  bool _keyboardOpen = false;

  double _keyboardHeight = 0.0;
  double _over = 0.0;

  bool dismissed = true;
  bool _dismissing = false;

  bool _hasScreenshot = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _channelReceiver = ChannelReceiver(() {
        _hasScreenshot = true;
      });
      _channelReceiver.init();
      ChannelManager.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    var bottom = MediaQuery.of(context).viewInsets.bottom;
    var keyboardOpen = bottom > 0;
    var oldKeyboardOpen = _keyboardOpen;
    _keyboardOpen = keyboardOpen;
    
    if (_keyboardOpen) {
      dismissed = false;
      _keyboardHeight = bottom;
      if(!oldKeyboardOpen && activePointer == null) {
        if(widget.onKeyboardOpen != null)
          widget.onKeyboardOpen!();
      }
    } else {
      // Close notification if the keyobard closes while not dragging
      if(oldKeyboardOpen && activePointer == null) {
        if(widget.onKeyboardClose != null)
          widget.onKeyboardClose!();
        dismissed = true;
      }
    }

    return Listener(
      onPointerDown: (details) {
        //print("pointerDown $dismissed $_isAnimating $activePointer $_keyboardOpen ${_pointers.length} $_dismissing");
        if ((!dismissed && !_dismissing) || _keyboardOpen) {
          _pointers.add(details.pointer);
          if (_pointers.length == 1) {
            if (Platform.isIOS) {
              ChannelManager.startScroll(
                  MediaQuery.of(context).viewInsets.bottom);
            }
            _lastPosition = details.position.dy;
            _lastTime = DateTime.now().millisecondsSinceEpoch;
            _velocities.clear();
          }
        }
      },
      onPointerUp: (details) {
        if (details.pointer == activePointer && _pointers.length == 1) {
          //print("pointerUp $_velocity, $_over, ${details.pointer}, $activePointer");
          if (_over > 0) {
            if (Platform.isIOS) {
              if (_velocity > 0.1 || _velocity < -0.3) {
                if (_velocity > 0) {
                  _dismissing = true;
                }
                ChannelManager.fling(_velocity).then((value) {
                  if (_velocity < 0) {
                    if (activePointer == null && !dismissed) {
                      showKeyboard(false);
                    }
                  } else {
                    _dismissing = false;
                    dismissed = true;
                    if(widget.onKeyboardClose != null)
                      widget.onKeyboardClose!();
                  }
                });
              } else {
                ChannelManager.expand().then((value) {
                  if (activePointer == null) {
                    showKeyboard(false);
                  }
                });
              }
            }
          }

          if (!Platform.isIOS) {
            if (!_keyboardOpen){
              dismissed = true;
              if(widget.onKeyboardClose != null)
                widget.onKeyboardClose!();
            }
          }
        }
        _pointers.remove(details.pointer);
      },
      onPointerMove: (details) {
        if (details.pointer == activePointer) {
          var position = details.position.dy;
          _over =
              position - (MediaQuery.of(context).size.height - _keyboardHeight);
          updateVelocity(position);
          //print("pointerMove $_over, $_isAnimating, $activePointer, ${details.pointer}");
          if (_over > 0) {
            if (Platform.isIOS) {
              if (_keyboardOpen && _hasScreenshot) hideKeyboard(false);
              ChannelManager.updateScroll(_over);
            } else {
              if (_velocity > 0.1) {
                if (_keyboardOpen) {
                  hideKeyboard(true);
                }
              } else if (_velocity < -0.5) {
                if (!_keyboardOpen){
                  showKeyboard(true);
                  if(widget.onKeyboardOpen != null)
                    widget.onKeyboardOpen!();
                }
              }
            }
          } else {
            if (Platform.isIOS) {
              ChannelManager.updateScroll(0.0);
              if (!_keyboardOpen) {
                showKeyboard(false);
              }
            } else {
              if (!_keyboardOpen){
                showKeyboard(true);
                if(widget.onKeyboardOpen != null)
                  widget.onKeyboardOpen!();
              }
            }
          }
        }
      },
      onPointerCancel: (details) {
        _pointers.remove(details.pointer);
      },
      child: widget.child,
    );
  }

  updateVelocity(double position) {
    var time = DateTime.now().millisecondsSinceEpoch;
    if (time - _lastTime > 0) {
      _velocity = (position - _lastPosition) / (time - _lastTime);
    }
    _lastPosition = position;
    _lastTime = time;
  }

  showKeyboard(bool animate) {
    if (!animate && Platform.isIOS) {
      ChannelManager.showKeyboard(true);
    } else {
      _showKeyboard();
    }
  }

  _showKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  hideKeyboard(bool animate) {
    if (!animate && Platform.isIOS) {
      ChannelManager.showKeyboard(false);
    } else {
      _hideKeyboard();
    }
  }

  _hideKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusScope.of(context).requestFocus(FocusNode());
  }
  
  Future<void> removeImageKeyboard()async{
    ChannelManager.updateScroll(_keyboardHeight);
  }

  Future<void> safeHideKeyboard()async {
    await removeImageKeyboard();
    _hideKeyboard();
  }
}

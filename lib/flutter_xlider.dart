import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// A material design slider and range slider with rtl support and lots of options and customizations for flutter
class FlutterSlider extends StatefulWidget {
  final Key key;
  final double divisions;
  final SizedBox handler;
  final SizedBox rightHandler;

  final Function(double lowerValue, double upperValue) onDragStarted;
  final Function(double lowerValue, double upperValue) onDragCompleted;
  final Function(double lowerValue, double upperValue) onDragging;
  final double min;
  final double max;
  final List<double> values;
  final bool rangeSlider;
  final bool rtl;
  final bool alwaysShowTooltip;
  final Color leftInactiveTrackBarColor;
  final Color rightInactiveTrackBarColor;
  final Color activeTrackBarColor;
  final double activeTrackBarHeight;
  final double inactiveTrackBarHeight;
  final bool jump;
  final List<SliderIgnoreSteps> ignoreSteps;
  final bool disabled;
  final int touchZone;
  final bool displayTestTouchZone;
  final TextStyle tooltipTextStyle;
  final FlutterSliderTooltip tooltipBox;
  final intl.NumberFormat tooltipNumberFormat;

  FlutterSlider(
      {this.key,
      @required this.min,
      @required this.max,
      @required this.values,
      this.handler,
      this.rightHandler,
      this.divisions,
      this.tooltipTextStyle =
          const TextStyle(fontSize: 12, color: Colors.black38),
      this.tooltipBox,
      this.onDragStarted,
      this.onDragCompleted,
      this.onDragging,
      this.rangeSlider = false,
      this.alwaysShowTooltip = false,
      this.leftInactiveTrackBarColor = const Color(0x110000ff),
      this.rightInactiveTrackBarColor = const Color(0x110000ff),
      this.activeTrackBarColor = const Color(0xff2196F3),
      this.activeTrackBarHeight = 3.5,
      this.inactiveTrackBarHeight = 3,
      this.rtl = false,
      this.jump = false,
      this.ignoreSteps = const [],
      this.disabled = false,
      this.touchZone = 2,
      this.displayTestTouchZone = false,
      this.tooltipNumberFormat})
      : assert(touchZone != null && (touchZone >= 1 && touchZone <= 5));

  @override
  _FlutterSliderState createState() => _FlutterSliderState();
}

class _FlutterSliderState extends State<FlutterSlider>
    with TickerProviderStateMixin {
  Widget leftHandler;
  Widget rightHandler;

  double leftHandlerXPosition = -1;
  double rightHandlerXPosition = 0;

  double _lowerValue = 0;
  double _upperValue = 0;
  double _outputLowerValue = 0;
  double _outputUpperValue = 0;

  double _fakeMin;
  double _fakeMax;

  double _divisions;
  double _power = 1;
  double _handlersPadding = 0;

  GlobalKey leftHandlerKey = GlobalKey();
  GlobalKey rightHandlerKey = GlobalKey();
  GlobalKey containerKey = GlobalKey();

  double _handlersWidth = 30;
  double _handlersHeight = 30;

  double _constraintMaxWidth;

//  double _constraintMaxHeight;
  double _containerWidthWithoutPadding;

//  double _containerHeightWithoutPadding;
  double _containerLeft = 0;

//  double _containerTop = 0;

  FlutterSliderTooltip _tooltipData;

  List<Function> _positionedItems;

  double _finalLeftHandlerWidth;
  double _finalRightHandlerWidth;
  double _finalLeftHandlerHeight;
  double _finalRightHandlerHeight;

  double _rightTooltipOpacity = 0;
  double _leftTooltipOpacity = 0;

  AnimationController _rightTooltipAnimationController;
  Animation<Offset> _rightTooltipAnimation;
  AnimationController _leftTooltipAnimationController;
  Animation<Offset> _leftTooltipAnimation;

  double _originalLowerValue;
  double _originalUpperValue;

  double _containerHeight;
  double _containerWidth;

  void _generateHandler() {
    if (widget.rightHandler == null) {
      rightHandler = RSDefaultHandler(
        id: rightHandlerKey,
        touchZone: widget.touchZone,
        displayTestTouchZone: widget.displayTestTouchZone,
        child: Icon(Icons.chevron_left, color: Colors.black38),
        handlerHeight: _handlersHeight,
        handlerWidth: _handlersWidth,
      );
    } else {
      _finalRightHandlerWidth = widget.rightHandler.width;
      _finalRightHandlerHeight = widget.rightHandler.height;
      rightHandler = RSInputHandler(
        id: rightHandlerKey,
        handler: widget.rightHandler,
        handlerWidth: _finalRightHandlerWidth,
        handlerHeight: _finalRightHandlerHeight,
        touchZone: widget.touchZone,
        displayTestTouchZone: widget.displayTestTouchZone,
      );
    }

    if (widget.handler == null) {
      IconData hIcon = Icons.chevron_right;
      if (widget.rtl && !widget.rangeSlider) {
        hIcon = Icons.chevron_left;
      }
      leftHandler = RSDefaultHandler(
        id: leftHandlerKey,
        touchZone: widget.touchZone,
        displayTestTouchZone: widget.displayTestTouchZone,
        child: Icon(hIcon, color: Colors.black38),
        handlerHeight: _handlersHeight,
        handlerWidth: _handlersWidth,
      );
    } else {
      _finalLeftHandlerWidth = widget.handler.width;
      _finalLeftHandlerHeight = widget.handler.height;
      leftHandler = RSInputHandler(
        id: leftHandlerKey,
        handler: widget.handler,
        handlerWidth: _finalLeftHandlerWidth,
        handlerHeight: _finalLeftHandlerHeight,
        touchZone: widget.touchZone,
        displayTestTouchZone: widget.displayTestTouchZone,
      );
    }

    if (widget.rangeSlider == false) {
      rightHandler = leftHandler;
    }
  }

  @override
  void initState() {
    // validate inputs
    _validations();

    // to display min of the range correctly.
    // if we use fakes, then min is always 0
    // so calculations works well, but when we want to display
    // result numbers to user, we add ( widget.min ) to the final numbers
    _fakeMin = 0;
    _fakeMax = widget.max - widget.min;

    // lower value. if not available then min will be used
    _originalLowerValue =
        (widget.values[0] != null) ? widget.values[0] : widget.min;
    if (widget.rangeSlider == true) {
      _originalUpperValue =
          (widget.values[1] != null) ? widget.values[1] : widget.max;
    } else {
      // when direction is rtl, then we use left handler. so to make right hand side
      // as blue ( as if selected ), then upper value should be max
      if (widget.rtl == true) {
        _originalUpperValue = widget.max;
      } else {
        // when direction is ltr, so we use right handler, to make left hand side of handler
        // as blue ( as if selected ), we set lower value to min, and upper value to (input lower value)
        _originalUpperValue = _originalLowerValue;
        _originalLowerValue = widget.min;
      }
    }

    _lowerValue = _originalLowerValue - widget.min;
    _upperValue = _originalUpperValue - widget.min;

    _rightTooltipOpacity = (widget.alwaysShowTooltip == true) ? 1 : 0;
    _leftTooltipOpacity = (widget.alwaysShowTooltip == true) ? 1 : 0;

    _outputLowerValue = _displayRealValue(_lowerValue);
    _outputUpperValue = _displayRealValue(_upperValue);

    if (widget.rtl == true) {
      _outputUpperValue = _displayRealValue(_lowerValue);
      _outputLowerValue = _displayRealValue(_upperValue);

      double tmpUpperValue = _fakeMax - _lowerValue;
      double tmpLowerValue = _fakeMax - _upperValue;

      _lowerValue = tmpLowerValue;
      _upperValue = tmpUpperValue;
    }

    _positionedItems = [
      _leftHandlerWidget,
      _rightHandlerWidget,
    ];

    _finalLeftHandlerWidth = _handlersWidth;
    _finalRightHandlerWidth = _handlersWidth;
    _finalLeftHandlerHeight = _handlersHeight;
    _finalRightHandlerHeight = _handlersHeight;

    _tooltipData = (widget.tooltipBox != null)
        ? widget.tooltipBox
        : FlutterSliderTooltip(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black12, width: 0.5),
                color: Color(0xffffffff)));

    if (widget.divisions != null) {
      _divisions = widget.divisions;
    } else {
      _divisions = (_fakeMax / 1000) < 1000 ? _fakeMax : (_fakeMax / 1000);
    }

    _generateHandler();

    _leftTooltipAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _leftTooltipAnimation =
        Tween<Offset>(begin: Offset(0, 0.20), end: Offset(0, -0.92)).animate(
            CurvedAnimation(
                parent: _leftTooltipAnimationController,
                curve: Curves.fastOutSlowIn));
    _rightTooltipAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _rightTooltipAnimation =
        Tween<Offset>(begin: Offset(0, 0.20), end: Offset(0, -0.92)).animate(
            CurvedAnimation(
                parent: _rightTooltipAnimationController,
                curve: Curves.fastOutSlowIn));

    WidgetsBinding.instance.addPostFrameCallback(_initialize);

    super.initState();
  }

  _initialize(_) {
    RenderBox containerRenderBox =
        containerKey.currentContext.findRenderObject();
    _containerLeft = containerRenderBox.localToGlobal(Offset.zero).dx;
//    _containerTop = containerRenderBox.localToGlobal(Offset.zero).dy;

//    print("CL:" + _containerLeft.toString());
//    print("CW:" + _constraintMaxWidth.toString());
//    print("Divisions:" + _divisions.toString());
//    print("Power:" + (_fakeMax / _divisions).toString());

    _handlersWidth = _finalLeftHandlerWidth;
    _handlersHeight = _finalLeftHandlerHeight;

    if (widget.rangeSlider == true &&
        _finalLeftHandlerWidth != _finalRightHandlerWidth) {
      throw 'ERROR: Width of both handlers should be equal';
    }

    if (widget.rangeSlider == true &&
        _finalLeftHandlerHeight != _finalRightHandlerHeight) {
      throw 'ERROR: Height of both handlers should be equal';
    }

//    if (leftHandlerKey.currentContext.size.height !=
//        rightHandlerKey.currentContext.size.height) {
//      throw 'ERROR: Height of both handlers should be equal';
//    }

//    print("HW:" + _handlersWidth.toString());
    _handlersPadding = _handlersWidth / 2;

//    print("CWWP: " + (_constraintMaxWidth - _handlersWidth).toString());

//    print("LOWER VVVVV" + _lowerValue.toString());
    leftHandlerXPosition =
        (((_constraintMaxWidth - _handlersWidth) / _fakeMax) * _lowerValue) -
            (widget.touchZone * 20 / 2);
    rightHandlerXPosition =
        ((_constraintMaxWidth - _handlersWidth) / _fakeMax) * _upperValue -
            (widget.touchZone * 20 / 2);

    setState(() {});

    if (_handlersWidth == null) {}
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      _constraintMaxWidth = constraints.maxWidth;
//          _constraintMaxHeight = constraints.maxHeight;
      _containerWidthWithoutPadding =
          _constraintMaxWidth - (_handlersPadding * 2);
      _power = _fakeMax / _divisions;

      _containerWidth = constraints.maxWidth;
      _containerHeight = (_handlersHeight * 1.8);

//          if (widget.axis == Axis.vertical) {
//            _containerWidth = (_handlersWidth * 1.8);
//            _containerHeight = constraints.maxHeight;
//          }

      return Container(
        key: containerKey,
        height: _containerHeight,
        width: _containerWidth,
        child: Stack(
          overflow: Overflow.visible,
          children: drawHandlers(),
        ),
      );
    });
  }

  void _validations() {
    if (widget.rangeSlider == true && widget.values.length < 2)
      throw 'when range mode is true, slider needs both lower and upper values';

    if (widget.values[0] != null && widget.values[0] < widget.min)
      throw 'Lower value should be greater than min';

    if (widget.rangeSlider == true) {
      if (widget.values[1] != null && widget.values[1] > widget.max)
        throw 'Upper value should be smaller than max';
    }
  }

  Positioned _leftHandlerWidget() {
    if (widget.rangeSlider == false)
      return Positioned(
        child: Container(),
      );

    return Positioned(
      key: Key('leftHandler'),
      left: leftHandlerXPosition,
      top: 0,
      bottom: 0,
      child: Listener(
        child: Draggable(
            onDragCompleted: () {},
            onDragStarted: () {
              if (widget.alwaysShowTooltip == false) {
                _leftTooltipOpacity = 1;
                _leftTooltipAnimationController.forward();
                setState(() {});
              }

              _callbacks('onDragStarted');
            },
            onDragEnd: (_) {
              if (_lowerValue >= (_fakeMax / 2)) {
                _positionedItems = [
                  _rightHandlerWidget,
                  _leftHandlerWidget,
                ];
              }

              if (widget.alwaysShowTooltip == false) {
                _leftTooltipOpacity = 0;
                _leftTooltipAnimationController.reset();
              }

              setState(() {});

              _callbacks('onDragCompleted');
            },
            axis: Axis.horizontal,
            child: Stack(
              overflow: Overflow.visible,
              children: <Widget>[
                _tooltip(
                    side: 'left',
                    value: _outputLowerValue,
                    opacity: _leftTooltipOpacity,
                    animation: _leftTooltipAnimation),
                leftHandler,
              ],
            ),
            feedback: Container()),
        onPointerMove: (_) {
          if (widget.disabled == true) return;
          double dx = _.position.dx - _containerLeft;

          double xPosTmp = dx - _handlersPadding;

//          print(xPosTmp);

          if (xPosTmp - (widget.touchZone * 20 / 2) <=
                      rightHandlerXPosition + 1 &&
                  dx >= _handlersPadding - 1 /* - _leftPadding*/
              ) {
            //xPosTmp - (_handlersPadding / 2);

            double rx =
                ((xPosTmp ~/ (_containerWidthWithoutPadding / _divisions)) *
                        _power)
                    .roundToDouble();

            if (widget.ignoreSteps.length > 0) {
              List<int> ignoreResult = [];
              for (SliderIgnoreSteps steps in widget.ignoreSteps) {
                if ((widget.rtl == false &&
                        (rx >= steps.from && rx <= steps.to) == false) ||
                    (widget.rtl == true &&
                        ((_fakeMax - rx) >= steps.from &&
                                (_fakeMax - rx) <= steps.to) ==
                            false)) {
                  ignoreResult.add(1);
                } else {
                  ignoreResult.add(0);
                }
              }
              if (ignoreResult.contains(0) == false) _lowerValue = rx;
            } else {
              _lowerValue = rx;
            }

            if (_lowerValue > _fakeMax) _lowerValue = _fakeMax;
            if (_lowerValue < _fakeMin) _lowerValue = _fakeMin;

            if (_lowerValue > _upperValue) _lowerValue = _upperValue;

            if (widget.jump == true) {
              leftHandlerXPosition =
                  (((_constraintMaxWidth - _handlersWidth) / _fakeMax) *
                          _lowerValue) -
                      (widget.touchZone * 20 / 2);
            } else {
              leftHandlerXPosition = xPosTmp - (widget.touchZone * 20 / 2);
            }

            _outputLowerValue = _displayRealValue(_lowerValue);
            if (widget.rtl == true) {
              _outputLowerValue = _displayRealValue(_fakeMax - _lowerValue);
            }
//            print("LOWER VALUE:" + _outputLowerValue.toString());

            setState(() {});
          }

          _callbacks('onDragging');
        },
        onPointerDown: (_) {},
      ),
    );
  }

  Positioned _rightHandlerWidget() {
    return Positioned(
      key: Key('rightHandler'),
      left: rightHandlerXPosition,
      top: 0,
      bottom: 0,
      child: Listener(
        child: Draggable(
            onDragCompleted: () {},
            onDragStarted: () {
              if (widget.alwaysShowTooltip == false) {
                _rightTooltipOpacity = 1;
                _rightTooltipAnimationController.forward();
                setState(() {});
              }

              _callbacks('onDragStarted');
            },
            onDragEnd: (_) {
              if (_upperValue <= (_fakeMax / 2)) {
                _positionedItems = [
                  _leftHandlerWidget,
                  _rightHandlerWidget,
                ];
              }

              if (widget.alwaysShowTooltip == false) {
                _rightTooltipOpacity = 0;
                _rightTooltipAnimationController.reset();
              }

              setState(() {});

              _callbacks('onDragCompleted');
            },
            axis: Axis.horizontal,
            child: Stack(
              overflow: Overflow.visible,
              children: <Widget>[
                _tooltip(
                    side: 'right',
                    value: _outputUpperValue,
                    opacity: _rightTooltipOpacity,
                    animation: _rightTooltipAnimation),
                rightHandler,
              ],
            ),
            feedback: Container(
//                            width: 20,
//                            height: 20,
//                            color: Colors.blue.withOpacity(0.7),
                )),
        onPointerMove: (_) {
          if (widget.disabled == true) return;

          double dx = _.position.dx - _containerLeft;
          double xPosTmp = dx - _handlersPadding;

//          print(xPosTmp);

          if (xPosTmp >=
                  leftHandlerXPosition - 1 + (widget.touchZone * 20 / 2) &&
              dx <= _constraintMaxWidth - _handlersPadding + 1) {
            double rx =
                ((xPosTmp ~/ (_containerWidthWithoutPadding / _divisions)) *
                        _power)
                    .roundToDouble();

//            _upperValue = rx;
//

            if (widget.ignoreSteps.length > 0) {
              List<int> ignoreResult = [];
              for (SliderIgnoreSteps steps in widget.ignoreSteps) {
                if ((widget.rtl == false &&
                        (rx >= steps.from && rx <= steps.to) == false) ||
                    (widget.rtl == true &&
                        ((_fakeMax - rx) >= steps.from &&
                                (_fakeMax - rx) <= steps.to) ==
                            false)) {
                  ignoreResult.add(1);
                } else {
                  ignoreResult.add(0);
                }
              }
              if (ignoreResult.contains(0) == false) _upperValue = rx;
            } else {
              _upperValue = rx;
            }

            if (_upperValue > _fakeMax) _upperValue = _fakeMax;
            if (_upperValue < _fakeMin) _upperValue = _fakeMin;

            if (_upperValue < _lowerValue) _upperValue = _lowerValue;

            if (widget.jump == true) {
              rightHandlerXPosition =
                  (((_constraintMaxWidth - _handlersWidth) / _fakeMax) *
                          _upperValue) -
                      (widget.touchZone * 20 / 2);
            } else {
              rightHandlerXPosition = xPosTmp - (widget.touchZone * 20 / 2);
            }

            //xPosTmp - (_handlersPadding / 2);

//            _upperValue =
//                ((xPosTmp ~/ (_containerWidthWithoutPadding / _divisions)) *
//                        _power)
//                    .roundToDouble();

            _outputUpperValue = _displayRealValue(_upperValue);
            if (widget.rtl == true) {
              _outputUpperValue = _displayRealValue(_fakeMax - _upperValue);
            }

            setState(() {});
          }

          _callbacks('onDragging');
        },
      ),
    );
  }

  drawHandlers() {
    List<Widget> items = [
      Function.apply(_leftInactiveTrack, []),
      Function.apply(_rightInactiveTrack, []),
      Function.apply(_activeTrack, []),
    ];

    for (Function func in _positionedItems) {
      items.add(Function.apply(func, []));
    }

    return items;
  }

  Positioned _tooltip(
      {String side, double value, double opacity, Animation animation}) {
    if (side == 'left') {
      if (widget.rangeSlider == false)
        return Positioned(
          child: Container(),
        );
    }
    String numberFormat;
    if (widget.tooltipNumberFormat == null)
      numberFormat = intl.NumberFormat().format(value);
    else
      numberFormat = widget.tooltipNumberFormat.format(value);

    Widget tooltipWidget = IgnorePointer(
        child: Center(
      child: Container(
        alignment: Alignment.center,
        child: Container(
            padding: EdgeInsets.all(8),
            decoration: _tooltipData.decoration,
            foregroundDecoration: _tooltipData.foregroundDecoration,
            transform: _tooltipData.transform,
            child: Text(numberFormat, style: widget.tooltipTextStyle)),
      ),
    ));

    double top = -(_containerHeight - _handlersHeight);
    if (widget.alwaysShowTooltip == false) {
      top = 0;
      tooltipWidget =
          SlideTransition(position: animation, child: tooltipWidget);
    }

    return Positioned(
      left: -20,
      right: -20,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: tooltipWidget,
      ),
    );
  }

  Positioned _leftInactiveTrack() {
    double width =
        leftHandlerXPosition - _handlersPadding + (widget.touchZone * 20 / 2);
    if (widget.rtl == true && widget.rangeSlider == false) {
      width = rightHandlerXPosition -
          _handlersPadding +
          (widget.touchZone * 20 / 2);
    }

    return Positioned(
      left: _handlersPadding,
      width: width,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          height: widget.inactiveTrackBarHeight,
          color: widget.leftInactiveTrackBarColor,
        ),
      ),
    );
  }

  Positioned _rightInactiveTrack() {
    double width = _constraintMaxWidth -
        rightHandlerXPosition -
        _handlersPadding -
        (widget.touchZone * 20 / 2);
//    if (widget.rangeSlider == true)
//      width = _constraintMaxWidth -
//          rightHandlerXPosition -
//          _handlersPadding -
//          (widget.touchZone * 20 / 2);

    return Positioned(
      left: rightHandlerXPosition + (widget.touchZone * 20 / 2),
      width: width,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          height: widget.inactiveTrackBarHeight,
          color: widget.rightInactiveTrackBarColor,
        ),
      ),
    );
  }

  Positioned _activeTrack() {
    double width = rightHandlerXPosition - leftHandlerXPosition;
    double left = leftHandlerXPosition + (widget.touchZone * 20 / 2);
    if (widget.rtl == true && widget.rangeSlider == false) {
      left = rightHandlerXPosition + (widget.touchZone * 20 / 2);
      width = _constraintMaxWidth -
          rightHandlerXPosition -
          (widget.touchZone * 20 / 2);
    }

    return Positioned(
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          height: widget.activeTrackBarHeight,
          color: widget.activeTrackBarColor,
        ),
      ),
    );
  }

  void _callbacks(String callbackName) {
    double lowerValue = _outputLowerValue;
    double upperValue = _outputUpperValue;
    if (widget.rtl == true || widget.rangeSlider == false) {
      lowerValue = _outputUpperValue;
      upperValue = _outputLowerValue;
    }

    switch (callbackName) {
      case 'onDragging':
        if (widget.onDragging != null)
          widget.onDragging(lowerValue, upperValue);
        break;
      case 'onDragCompleted':
        if (widget.onDragCompleted != null)
          widget.onDragCompleted(lowerValue, upperValue);
        break;
      case 'onDragStarted':
        if (widget.onDragStarted != null)
          widget.onDragStarted(lowerValue, upperValue);
        break;
    }
  }

  double _displayRealValue(double value) {
    return value + widget.min;
  }
}

class RSDefaultHandler extends StatelessWidget {
  final GlobalKey id;
  final Widget child;
  final double handlerWidth;
  final double handlerHeight;
  final int touchZone;
  final bool displayTestTouchZone;

  RSDefaultHandler(
      {this.id,
      this.child,
      this.handlerWidth,
      this.handlerHeight,
      this.touchZone,
      this.displayTestTouchZone});

  @override
  Widget build(BuildContext context) {
    double touchOpacity = (displayTestTouchZone == true) ? 1 : 0;

    return Container(
      key: id,
      width: handlerWidth + touchZone * 20,
      child: Stack(children: <Widget>[
        Opacity(
          opacity: touchOpacity,
          child: Container(
            color: Colors.black12,
            child: Container(),
          ),
        ),
        Center(
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
//          border: Border.all(color: Colors.lightBlue, width: 4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      spreadRadius: 0.2,
                      offset: Offset(0, 1))
                ], color: Colors.white, shape: BoxShape.circle),
            width: handlerWidth,
            height: handlerHeight,
            child: child,
          ),
        )
      ]),
    );
  }
}

class RSInputHandler extends StatelessWidget {
  final GlobalKey id;
  final SizedBox handler;
  final double handlerWidth;
  final double handlerHeight;
  final int touchZone;
  final bool displayTestTouchZone;

  RSInputHandler(
      {this.id,
      this.handler,
      this.handlerWidth,
      this.handlerHeight,
      this.touchZone,
      this.displayTestTouchZone});

  @override
  Widget build(BuildContext context) {
    double touchOpacity = (displayTestTouchZone == true) ? 1 : 0;

    return Container(
        key: id,
        width: handlerWidth + touchZone * 20,
        child: Stack(children: <Widget>[
          Opacity(
            opacity: touchOpacity,
            child: Container(
              color: Colors.black12,
              child: Container(),
            ),
          ),
          Center(
              child: Container(
            height: handler.height,
            width: handler.width,
            child: handler.child,
          ))
        ]));
  }
}

class FlutterSliderTooltip {
  final BoxDecoration decoration;
  final BoxDecoration foregroundDecoration;
  final Matrix4 transform;

  FlutterSliderTooltip(
      {this.decoration, this.foregroundDecoration, this.transform});
}

class SliderIgnoreSteps {
  final double from;
  final double to;

  SliderIgnoreSteps({this.from, this.to})
      : assert(from != null && to != null && from <= to);
}

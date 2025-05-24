import 'dart:async';
import 'dart:ui' as ui;

import 'package:device_frame_plus/device_frame_plus.dart';
import 'package:device_preview_plus/src/state/state.dart';
import 'package:device_preview_plus/src/state/store.dart';
import 'package:device_preview_plus/src/storage/storage.dart';
import 'package:device_preview_plus/src/utilities/assert_inherited_media_query.dart';
import 'package:device_preview_plus/src/utilities/media_query_observer.dart';
import 'package:device_preview_plus/src/views/theme.dart';
import 'package:device_preview_plus/src/views/tool_panel/sections/accessibility.dart';
import 'package:device_preview_plus/src/views/tool_panel/sections/device.dart';
import 'package:device_preview_plus/src/views/tool_panel/sections/settings.dart';
import 'package:device_preview_plus/src/views/tool_panel/sections/system.dart';
import 'package:device_preview_plus/src/views/tool_panel/tool_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'locales/default_locales.dart';
import 'utilities/screenshot.dart';
import 'views/large.dart';
import 'views/small.dart';

/// Simulates how the result of [builder] would render on different
/// devices.
///
/// {@tool snippet}
///
/// This sample shows how to define an app with a plugin.
///
/// ```dart
/// DevicePreview(
///   builder: (context) => MaterialApp(
///      useInheritedMediaQuery: true,
///      locale: DevicePreview.locale(context),
///      builder: DevicePreview.appBuilder,
///      theme: ThemeData.light(),
///      darkTheme: ThemeData.dark(),
///      home: const Home(),
///    ),
/// )
/// ```
/// {@end-tool}
///
/// See also :
/// * [Devices] has a set of predefined common devices.
class DevicePreview extends StatefulWidget {
  /// Create a new [DevicePreview].
  const DevicePreview({
    super.key,
    required this.builder,
    this.devices,
    this.data,
    this.isToolbarVisible = true,
    this.availableLocales,
    this.defaultDevice,
    this.tools = defaultTools,
    this.storage,
    this.enabled = true,
    this.backgroundColor,
    this.hideAppBar = false,
    this.hideBottomBar = false,
    this.hideBoxAroundDevice = false,
  });

  /// Creates a [DevicePreview] instance that is optimized for a clean preview,
  /// with toolbars and extra UI elements hidden by default.
  ///
  /// This factory constructor calls the default constructor, setting
  /// [isToolbarVisible] to `false`, and [hideAppBar], [hideBottomBar],
  /// and [hideBoxAroundDevice] to `true` to achieve a clean preview.
  factory DevicePreview.builder({
    Key? key,
    required WidgetBuilder builder,
    List<DeviceInfo>? devices,
    DevicePreviewData? data,
    List<Locale>? availableLocales,
    DeviceInfo? defaultDevice,
    List<Widget> tools = defaultTools,
    DevicePreviewStorage? storage,
    bool enabled = true,
    Color? backgroundColor,
    // Note: isToolbarVisible, hideAppBar, hideBottomBar, hideBoxAroundDevice
    // are not accepted as parameters here. They are intentionally overridden.
  }) {
    return DevicePreview(
      key: key,
      builder: builder,
      devices: devices,
      data: data,
      isToolbarVisible: false, // Hardcoded for clean preview
      availableLocales: availableLocales,
      defaultDevice: defaultDevice,
      tools: tools,
      storage: storage,
      enabled: enabled,
      backgroundColor: backgroundColor,
      hideAppBar: true, // Hardcoded for clean preview
      hideBottomBar: true, // Hardcoded for clean preview
      hideBoxAroundDevice: true, // Hardcoded for clean preview
    );
  }

  /// If not [enabled], the [child] is used directly.
  final bool enabled;

  /// Indicates whether the tool bar should be visible or not.
  final bool isToolbarVisible;

  /// The configuration. If not precised, it is loaded from preferences.
  final DevicePreviewData? data;

  /// The previewed widget.
  ///
  /// It is common to give the root application widget.
  final WidgetBuilder builder;

  /// The background color of the canvas
  ///
  /// Overrides `theme.canvasColor`
  final Color? backgroundColor;

  /// The default selected device when opening device preview for the first time.
  final DeviceInfo? defaultDevice;

  /// The available devices used for previewing.
  final List<DeviceInfo>? devices;

  /// The list of available tools.
  ///
  /// All the tools must be [Sliver]s and will be added to the menu.
  final List<Widget> tools;

  /// The available locales.
  final List<Locale>? availableLocales;

  /// The storage used to persist preferences.
  ///
  /// By default, it saves preferences to the local device preferences.
  ///
  /// To disable settings persistence use `DevicePreviewStorage.none()`.
  final DevicePreviewStorage? storage;

  /// Hide the app bar of the device preview.
  final bool? hideAppBar;

  /// Hide the bottom bar of the device preview.
  final bool? hideBottomBar;

  /// Hide the box around the device preview.
  final bool? hideBoxAroundDevice;

  /// All the default available devices.
  static final List<DeviceInfo> defaultDevices = Devices.all;

  /// All the default tools included in the menu : [DeviceSection], [SystemSection],
  /// [AccessibilitySection] and [SettingsSection].
  static const List<Widget> defaultTools = <Widget>[
    DeviceSection(),
    SystemSection(),
    AccessibilitySection(),
    SettingsSection(),
  ];

  @override
  DevicePreviewWidgetState createState() => DevicePreviewWidgetState();

  /// The currently selected device.
  static DeviceInfo selectedDevice(BuildContext context) {
    return context.select((DevicePreviewStore store) => store.deviceInfo);
  }

  /// The simulated target platform for the currently selected device.
  static TargetPlatform platform(BuildContext context) {
    final platform = context.select(
      (DevicePreviewStore store) => store.deviceInfo.identifier.platform,
    );
    return platform;
  }

  /// The simulated visual density for the currently selected device.
  static VisualDensity visualDensity(BuildContext context) {
    final deviceType = context.select(
      (DevicePreviewStore store) => store.deviceInfo.identifier.type,
    );
    if (deviceType == DeviceType.desktop || deviceType == DeviceType.laptop) {
      return VisualDensity.compact;
    }
    return VisualDensity.standard;
  }

  /// Create a new [ThemeData] from the given [data], but with updated properties from
  /// the currently simulated device.
  static Widget appBuilder(BuildContext context, Widget? child) {
    if (!_isEnabled(context)) {
      return child!;
    }

    final theme = Theme.of(context);
    final isInitializedAndEnabled = context.select(
      (DevicePreviewStore store) => store.state.maybeMap(
        initialized: (initialized) => initialized.data.isEnabled,
        orElse: () => false,
      ),
    );

    if (!isInitializedAndEnabled) {
      return child!;
    }

    return Theme(
      data: theme.copyWith(
        platform: platform(context),
        visualDensity: visualDensity(context),
      ),
      child: child!,
    );
  }

  /// Indicates whether the device preview is currently enabled.
  static bool isEnabled(BuildContext context) {
    if (_isEnabled(context)) {
      return context.select(
        (DevicePreviewStore store) => store.state.maybeMap(
          initialized: (initialized) => initialized.data.isEnabled,
          orElse: () => false,
        ),
      );
    }
    return false;
  }

  static bool _isEnabled(BuildContext context) {
    final state = context.findAncestorStateOfType<DevicePreviewWidgetState>();
    return state != null && state.widget.enabled;
  }

  /// Currently defined locale.
  static Locale? locale(BuildContext context) {
    if (!_isEnabled(context)) {
      return null;
    }

    final store = Provider.of<DevicePreviewStore>(context);
    return store.state.maybeMap(
      initialized: (state) {
        final splits = state.data.locale.split('_');
        final languageCode = splits[0];
        String? scriptCode, countryCode;
        if (splits.length > 2) {
          scriptCode = splits[1];
          countryCode = splits[2];
        } else if (splits.length > 1) {
          countryCode = splits[1];
        }
        return Locale.fromSubtags(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        );
      },
      orElse: () => View.of(context).platformDispatcher.locale,
    );
  }

  /// Make the toolbar visible to the user.
  ///
  /// If [enablePreview] is set to `true`, then the device preview is also enabled
  /// when appearing.
  static void showToolbar(BuildContext context, {bool enablePreview = true}) {
    final store = Provider.of<DevicePreviewStore>(context);
    store.data = store.data.copyWith(
      isToolbarVisible: true,
      isEnabled: enablePreview,
    );
  }

  /// Hide the toolbar.
  ///
  /// If [disablePreview] is set to `false`, then the device preview stays active even
  /// if the toolbar is not visible anymore.
  static void hideToolbar(BuildContext context, {bool disablePreview = true}) {
    final store = Provider.of<DevicePreviewStore>(context);
    store.data = store.data.copyWith(
      isToolbarVisible: false,
      isEnabled: !disablePreview,
    );
  }

  /// Select a device from its unique [deviceIdentifier].
  ///
  /// All the identifiers are available from [Devices].
  static void selectDevice(
    BuildContext context,
    DeviceIdentifier deviceIdentifier,
  ) {
    final store = Provider.of<DevicePreviewStore>(context, listen: false);
    store.selectDevice(deviceIdentifier);
  }

  /// The list of all available device identifiers.
  static List<DeviceIdentifier> availableDeviceIdentifiers(
    BuildContext context,
  ) {
    final store = Provider.of<DevicePreviewStore>(context, listen: false);
    return store.devices.map((info) => info.identifier).toList();
  }

  /// All available locales in the tool.
  static List<Locale> allLocales(BuildContext context) {
    if (!_isEnabled(context)) {
      return defaultAvailableLocales.map((e) => Locale(e.code)).toList();
    }
    final store = Provider.of<DevicePreviewStore>(context);
    return store.state
        .maybeMap(
          initialized: (state) => state.locales,
          orElse: () => defaultAvailableLocales,
        )
        .map((e) => Locale(e.code))
        .toList();
  }

  /// Take a screenshot.
  static Future<DeviceScreenshot> screenshot(BuildContext context) {
    final state = context.findAncestorStateOfType<DevicePreviewWidgetState>();
    final store = context.read<DevicePreviewStore>();
    return state!.screenshot(store);
  }

  static MediaQueryData _mediaQuery(BuildContext context) {
    final device = context.select(
      (DevicePreviewStore store) => store.deviceInfo,
    );

    final orientation = context.select(
      (DevicePreviewStore store) => store.data.orientation,
    );

    final isVirtualKeyboardVisible = context.select(
      (DevicePreviewStore store) => store.data.isVirtualKeyboardVisible,
    );

    final isDarkMode = context.select(
      (DevicePreviewStore store) => store.data.isDarkMode,
    );

    final textScaleFactor = context.select(
      (DevicePreviewStore store) => store.data.textScaleFactor,
    );

    final boldText = context.select(
      (DevicePreviewStore store) => store.data.boldText,
    );

    final disableAnimations = context.select(
      (DevicePreviewStore store) => store.data.disableAnimations,
    );

    final accessibleNavigation = context.select(
      (DevicePreviewStore store) => store.data.accessibleNavigation,
    );

    final invertColors = context.select(
      (DevicePreviewStore store) => store.data.invertColors,
    );

    var mediaQuery = DeviceFrame.mediaQuery(
      context: context,
      info: device,
      orientation: orientation,
    );

    if (isVirtualKeyboardVisible) {
      mediaQuery = VirtualKeyboard.mediaQuery(mediaQuery);
    }

    return mediaQuery.copyWith(
      platformBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      boldText: boldText,
      textScaler: TextScaler.linear(textScaleFactor),
      disableAnimations: disableAnimations,
      accessibleNavigation: accessibleNavigation,
      invertColors: invertColors,
    );
  }
}

class DevicePreviewWidgetState extends State<DevicePreview> {
  bool _isToolPanelPopOverOpen = false;

  late DevicePreviewStorage storage =
      widget.storage ?? DevicePreviewStorage.preferences();

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  /// Whenever the [screenshot] is called, a new value is pushed to
  /// this stream.
  Stream<DeviceScreenshot> get onScreenshot => _onScreenshot!.stream;

  /// Takes a screenshot with the current configuration.
  Future<DeviceScreenshot> screenshot(DevicePreviewStore store) async {
    final boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    const format = ui.ImageByteFormat.png;

    final image = await boundary.toImage(
      pixelRatio: store.deviceInfo.pixelRatio,
    );
    final byteData = await image.toByteData(format: format);
    final bytes = byteData!.buffer.asUint8List();
    final screenshot = DeviceScreenshot(
      device: store.deviceInfo,
      bytes: bytes,
      format: format,
    );
    _onScreenshot?.add(screenshot);
    return screenshot;
  }

  @override
  void initState() {
    _onScreenshot = StreamController<DeviceScreenshot>.broadcast();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DevicePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage && widget.storage != null) {
      storage = widget.storage!;
    }
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = context.select(
      (DevicePreviewStore store) => store.state.maybeMap(
        initialized: (state) => state.data.isEnabled,
        orElse: () => false,
      ),
    );

    if (!isEnabled) return widget.builder(context);

    final mediaQuery = MediaQuery.of(context);
    final device = context.select(
      (DevicePreviewStore store) => store.deviceInfo,
    );
    final isFrameVisible = context.select(
      (DevicePreviewStore store) => store.data.isFrameVisible,
    );
    final orientation = context.select(
      (DevicePreviewStore store) => store.data.orientation,
    );
    final isVirtualKeyboardVisible = context.select(
      (DevicePreviewStore store) => store.data.isVirtualKeyboardVisible,
    );
    final isDarkMode = context.select(
      (DevicePreviewStore store) => store.data.isDarkMode,
    );

    final bool shouldHideBoxAroundDevice = widget.hideBoxAroundDevice ?? false;

    return Container(
      color: widget.backgroundColor ?? theme.canvasColor,
      padding:
          shouldHideBoxAroundDevice
              ? EdgeInsets.zero
              : EdgeInsets.only(
                top: 20 + mediaQuery.viewPadding.top,
                right: 20 + mediaQuery.viewPadding.right,
                left: 20 + mediaQuery.viewPadding.left,
                bottom: 20,
              ),
      child: FittedBox(
        fit: BoxFit.contain,
        child: RepaintBoundary(
          key: _repaintKey,
          child: DeviceFrame(
            device: device,
            isFrameVisible: isFrameVisible,
            orientation: orientation,
            screen: VirtualKeyboard(
              isEnabled: isVirtualKeyboardVisible,
              child: Theme(
                data: Theme.of(context).copyWith(
                  platform: device.identifier.platform,
                  brightness: isDarkMode ? Brightness.dark : Brightness.light,
                ),
                child: MediaQuery(
                  data: DevicePreview._mediaQuery(context),
                  child: Builder(
                    key: _appKey,
                    builder: (context) {
                      final app = widget.builder(context);
                      assert(
                        isWidgetsAppUsingInheritedMediaQuery(app),
                        'Your widgets app should have its `useInheritedMediaQuery` property set to `true` in order to use DevicePreview.',
                      );
                      return app;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Builder(key: _appKey, builder: widget.builder);
    }
    final preferredLocales = View.of(context).platformDispatcher.locales;

    return ChangeNotifierProvider(
      create:
          (context) => DevicePreviewStore(
            defaultDevice: widget.defaultDevice ?? Devices.ios.iPhone13,
            devices: widget.devices,
            preferredLocales: preferredLocales,
            availableLocales: widget.availableLocales,
            storage: storage,
          ),
      builder: (context, child) {
        final isInitialized = context.select(
          (DevicePreviewStore store) => store.state.maybeMap(
            initialized: (_) => true,
            orElse: () => false,
          ),
        );

        if (!isInitialized) {
          return Builder(key: _appKey, builder: widget.builder);
        }

        final isEnabled = context.select(
          (DevicePreviewStore store) => store.data.isEnabled,
        );

        final toolbarTheme = context.select(
          (DevicePreviewStore store) => store.settings.toolbarTheme,
        );

        final backgroundTheme = context.select(
          (DevicePreviewStore store) => store.settings.backgroundTheme,
        );

        final isToolbarVisible =
            widget.isToolbarVisible &&
            context.select(
              (DevicePreviewStore store) => store.data.isToolbarVisible,
            );

        final toolbar = toolbarTheme.asThemeData();
        final background = backgroundTheme.asThemeData();
        return Directionality(
          textDirection: TextDirection.ltr,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: MediaQueryObserver(
              //mediaQuery: DevicePreview._mediaQuery(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: toolbar.scaffoldBackgroundColor,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final mediaQuery = MediaQuery.of(context);
                    final isSmall = constraints.maxWidth < 700;
                    final bool shouldHideBoxAroundDevice =
                        widget.hideBoxAroundDevice ?? false;

                    final BorderRadius borderRadius =
                        isToolbarVisible && !shouldHideBoxAroundDevice
                            ? BorderRadius.only(
                              topRight:
                                  isSmall
                                      ? Radius.zero
                                      : const Radius.circular(16),
                              bottomRight: const Radius.circular(16),
                              bottomLeft:
                                  isSmall
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                            )
                            : BorderRadius.zero;

                    // Calculate offsets based on whether the respective toolbars will actually be visible.
                    final double rightPanelOffset =
                        !isSmall
                            ? (isEnabled
                                ? ToolPanel.panelWidth - 10
                                : (64 + mediaQuery.padding.right))
                            : 0;

                    // Visibility for the small layout's bottom bar part (assuming it's part of DevicePreviewSmallLayout)
                    // For now, if shouldHideBottomBar is true, we adjust the bottomPanelOffset.
                    final bool shouldHideAppBar = widget.hideAppBar ?? false;
                    final bool shouldHideBottomBar =
                        widget.hideBottomBar ?? false;

                    // Determine if the small layout's toolbar should be rendered at all.
                    // It's rendered if the global toolbar is visible and it's a small layout.
                    // The SmallLayout itself will hide its content based on its own hideAppBar/hideBottomBar props.
                    final bool renderSmallLayout = isToolbarVisible && isSmall;

                    // Determine if the large layout's toolbar should be rendered.
                    final bool renderLargeLayout =
                        isToolbarVisible && !isSmall && !shouldHideAppBar;

                    // Small layout's toolbar (which is at the bottom) is hidden if either its hideAppBar or hideBottomBar is true.
                    final bool isSmallLayoutToolbarHidden =
                        shouldHideAppBar || shouldHideBottomBar;
                    final double bottomPanelOffset =
                        renderSmallLayout &&
                                !isSmallLayoutToolbarHidden // only apply if small layout toolbar is rendered and not internally hidden
                            ? mediaQuery.padding.bottom + 52
                            : 0;

                    // Determine if any part of the toolbar UI is effectively visible for positioning the preview
                    final bool anyToolbarUiVisible =
                        (renderSmallLayout && !isSmallLayoutToolbarHidden) ||
                        renderLargeLayout;

                    return Stack(
                      children: <Widget>[
                        if (renderSmallLayout)
                          Positioned(
                            key: const Key('Small'),
                            bottom: 0,
                            right: 0,
                            left: 0,
                            child: DevicePreviewSmallLayout(
                              slivers: widget.tools,
                              maxMenuHeight: constraints.maxHeight * 0.5,
                              scaffoldKey: scaffoldKey,
                              onMenuVisibleChanged:
                                  (isVisible) => setState(() {
                                    _isToolPanelPopOverOpen = isVisible;
                                  }),
                              hideAppBar: shouldHideAppBar,
                              hideBottomBar: shouldHideBottomBar,
                            ),
                          ),
                        if (renderLargeLayout)
                          Positioned.fill(
                            key: const Key('Large'),
                            child: DervicePreviewLargeLayout(
                              slivers: widget.tools,
                            ),
                          ),
                        AnimatedPositioned(
                          key: const Key('preview'),
                          duration: const Duration(milliseconds: 200),
                          left: 0,
                          right: anyToolbarUiVisible ? rightPanelOffset : 0,
                          top: 0,
                          bottom: anyToolbarUiVisible ? bottomPanelOffset : 0,
                          child: Theme(
                            data: background,
                            child: Container(
                              decoration:
                                  shouldHideBoxAroundDevice
                                      ? null
                                      : BoxDecoration(
                                        boxShadow: const [
                                          BoxShadow(
                                            blurRadius: 20,
                                            color: Color(0xAA000000),
                                          ),
                                        ],
                                        borderRadius: borderRadius,
                                        color:
                                            background.scaffoldBackgroundColor,
                                      ),
                              child: ClipRRect(
                                borderRadius:
                                    borderRadius, // borderRadius is already Zero if shouldHideBoxAroundDevice is true
                                child:
                                    isEnabled
                                        ? Builder(builder: _buildPreview)
                                        : Builder(
                                          key: _appKey,
                                          builder: widget.builder,
                                        ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: !_isToolPanelPopOverOpen,
                            child: Localizations(
                              locale: const Locale('en', 'US'),
                              delegates: const [
                                GlobalMaterialLocalizations.delegate,
                                GlobalCupertinoLocalizations.delegate,
                                GlobalWidgetsLocalizations.delegate,
                              ],
                              child: Navigator(
                                onGenerateInitialRoutes: (navigator, name) {
                                  return [
                                    MaterialPageRoute(
                                      builder:
                                          (context) => Scaffold(
                                            key: scaffoldKey,
                                            backgroundColor: Colors.transparent,
                                          ),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The repaint key used for rendering screenshots.
  final _repaintKey = GlobalKey();

  /// A stream that sends a new value each time the user takes
  /// a new screenshot.
  StreamController<DeviceScreenshot>? _onScreenshot;

  /// The current application key.
  final GlobalKey _appKey = GlobalKey();
}

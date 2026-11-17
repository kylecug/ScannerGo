#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - 扫码页面

@interface ScannerViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) UIView *previewView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, copy) NSString *lastValue;
@property (nonatomic, strong) NSDate *lastTime;
@property (nonatomic, strong) UIButton *openButton;
@property (nonatomic, strong) NSURL *pendingURL;
@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, strong) UIView *focusBox;
@end

static NSString *const kSavedTextKey = @"ScannedText";

@implementation ScannerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"scannerGo";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.sessionQueue = dispatch_queue_create("scanner.session", DISPATCH_QUEUE_SERIAL);

    // 摄像头预览区
    self.previewView = [UIView new];
    self.previewView.backgroundColor = [UIColor blackColor];
    self.previewView.layer.cornerRadius = 12;
    self.previewView.clipsToBounds = YES;
    self.previewView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.previewView];

    self.statusLabel = [UILabel new];
    self.statusLabel.text = @"对准二维码 / 条形码";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.previewView addSubview:self.statusLabel];

    // 识别到网址时出现的"打开链接"按钮（不会自动打开，要自己点）
    self.openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openButton setTitle:@"  打开链接  " forState:UIControlStateNormal];
    [self.openButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.openButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.openButton.backgroundColor = [UIColor systemBlueColor];
    self.openButton.layer.cornerRadius = 16;
    self.openButton.hidden = YES;
    self.openButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.openButton addTarget:self action:@selector(openLink) forControlEvents:UIControlEventTouchUpInside];
    [self.previewView addSubview:self.openButton];

    // 点画面对焦
    self.focusBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 72, 72)];
    self.focusBox.layer.borderColor = [UIColor systemYellowColor].CGColor;
    self.focusBox.layer.borderWidth = 2;
    self.focusBox.alpha = 0;
    self.focusBox.userInteractionEnabled = NO;
    [self.previewView addSubview:self.focusBox];
    [self.previewView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapToFocus:)]];

    // 结果文本框
    self.textView = [UITextView new];
    self.textView.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    self.textView.layer.borderColor = [UIColor separatorColor].CGColor;
    self.textView.layer.borderWidth = 1;
    self.textView.layer.cornerRadius = 12;
    self.textView.textContainerInset = UIEdgeInsetsMake(10, 8, 10, 8);
    self.textView.text = [[NSUserDefaults standardUserDefaults] stringForKey:kSavedTextKey] ?: @"";
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.textView];

    // 键盘上加个"完成"
    UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    bar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissKeyboard)]];
    [bar sizeToFit];
    self.textView.inputAccessoryView = bar;

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearText)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"复制" style:UIBarButtonItemStylePlain target:self action:@selector(copyText)];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.previewView.topAnchor constraintEqualToAnchor:g.topAnchor constant:12],
        [self.previewView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [self.previewView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [self.previewView.heightAnchor constraintEqualToAnchor:g.heightAnchor multiplier:0.5],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.previewView.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.previewView.trailingAnchor],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.previewView.bottomAnchor],
        [self.statusLabel.heightAnchor constraintGreaterThanOrEqualToConstant:32],

        [self.openButton.topAnchor constraintEqualToAnchor:self.previewView.topAnchor constant:12],
        [self.openButton.trailingAnchor constraintEqualToAnchor:self.previewView.trailingAnchor constant:-12],
        [self.openButton.heightAnchor constraintEqualToConstant:32],

        [self.textView.topAnchor constraintEqualToAnchor:self.previewView.bottomAnchor constant:12],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.previewView.leadingAnchor],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.previewView.trailingAnchor],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-12],
    ]];

    [self requestCameraAndStart];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.previewLayer.frame = self.previewView.bounds;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startSession];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    dispatch_async(self.sessionQueue, ^{ if (self.session.isRunning) [self.session stopRunning]; });
}

#pragma mark 相机

- (void)requestCameraAndStart {
    AVAuthorizationStatus st = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (st == AVAuthorizationStatusAuthorized) {
        [self setupSession];
    } else if (st == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) [self setupSession]; else [self showStatus:@"没有相机权限，请到 设置 里打开"];
            });
        }];
    } else {
        [self showStatus:@"没有相机权限，请到 设置 里打开"];
    }
}

- (void)setupSession {
    // 优先用带超广角的虚拟镜头（Pro 机型三摄 / 双广角），凑近时系统会像相机 App 一样自动切微距；
    // 没有的话用广角主摄，找不到再退回默认摄像头
    AVCaptureDeviceDiscoverySession *ds = [AVCaptureDeviceDiscoverySession
        discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInTripleCamera,
                                          AVCaptureDeviceTypeBuiltInDualWideCamera,
                                          AVCaptureDeviceTypeBuiltInWideAngleCamera]
                              mediaType:AVMediaTypeVideo
                               position:AVCaptureDevicePositionBack];
    AVCaptureDevice *device = ds.devices.firstObject ?: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *err = nil;
    AVCaptureDeviceInput *input = device ? [AVCaptureDeviceInput deviceInputWithDevice:device error:&err] : nil;
    if (!input) { [self showStatus:[NSString stringWithFormat:@"打不开摄像头：%@", err.localizedDescription ?: @"无设备"]]; return; }

    AVCaptureSession *session = [AVCaptureSession new];
    session.sessionPreset = AVCaptureSessionPresetHigh;
    if ([session canAddInput:input]) [session addInput:input];

    AVCaptureMetadataOutput *output = [AVCaptureMetadataOutput new];
    if (![session canAddOutput:output]) { [self showStatus:@"无法添加识别输出"]; return; }
    [session addOutput:output];
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];

    NSArray *wanted = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code,
                        AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode128Code, AVMetadataObjectTypeCode39Code,
                        AVMetadataObjectTypeCode39Mod43Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypePDF417Code,
                        AVMetadataObjectTypeAztecCode, AVMetadataObjectTypeDataMatrixCode, AVMetadataObjectTypeITF14Code,
                        AVMetadataObjectTypeInterleaved2of5Code];
    NSMutableArray *types = [NSMutableArray array];
    for (NSString *t in wanted) if ([output.availableMetadataObjectTypes containsObject:t]) [types addObject:t];
    output.metadataObjectTypes = types;

    self.session = session;
    self.device = device;
    [self configureFocusForDevice:device];
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.previewView.bounds;
    [self.previewView.layer insertSublayer:self.previewLayer atIndex:0];
    [self startSession];
}

#pragma mark 对焦

// 码在画面里大概占多宽（0~1），以及要能扫到的最小码宽（毫米）
static const float kPreviewFill = 0.6f;
static const float kMinCodeSizeMM = 20.0f;

- (void)configureFocusForDevice:(AVCaptureDevice *)d {
    NSError *err = nil;
    if (![d lockForConfiguration:&err]) return;

    if ([d isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) d.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    if (d.isAutoFocusRangeRestrictionSupported) d.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear; // 优先近距离
    if (d.isSmoothAutoFocusSupported) d.smoothAutoFocusEnabled = NO;                                              // 对焦快一点
    if (d.isFocusPointOfInterestSupported) d.focusPointOfInterest = CGPointMake(0.5, 0.5);
    if ([d isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) d.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    if (d.isExposurePointOfInterestSupported) d.exposurePointOfInterest = CGPointMake(0.5, 0.5);

    BOOL macro = NO;
    NSArray<NSNumber *> *switchOver = d.virtualDeviceSwitchOverVideoZoomFactors;
    if (d.isVirtualDevice && switchOver.count > 0) {
        // 虚拟镜头：zoom 1.0 是超广角，第一个切换点就是"1x 主摄"视角。
        // 停在这里，凑近对不上焦时系统自动切到超广角微距（15 Pro / Pro Max 最近约 2cm）。
        if (@available(iOS 15.0, *)) {
            [d setPrimaryConstituentDeviceSwitchingBehavior:AVCapturePrimaryConstituentDeviceSwitchingBehaviorAuto
                             restrictedSwitchingBehaviorConditions:AVCapturePrimaryConstituentDeviceRestrictedSwitchingBehaviorConditionNone];
        }
        d.videoZoomFactor = MIN(switchOver.firstObject.doubleValue, d.activeFormat.videoMaxZoomFactor);
        macro = YES;
    }

    // 没有超广角的机型：主摄最近对焦距离比较远（十几厘米），贴近就糊。
    // 按 Apple 扫码示例的做法自动放大一点：人站在最近对焦距离之外，码在画面里也够大。
    NSInteger minFocusMM = d.minimumFocusDistance; // iOS 15+，单位毫米，-1 表示未知
    float fov = d.activeFormat.videoFieldOfView;
    if (!macro && minFocusMM > 0 && fov > 0) {
        float halfRad = (fov / 2.0f) * (float)M_PI / 180.0f;
        float minSubjectMM = (kMinCodeSizeMM / kPreviewFill) / tanf(halfRad);
        if (minSubjectMM < minFocusMM) {
            CGFloat zoom = MIN((CGFloat)(minFocusMM / minSubjectMM), d.activeFormat.videoMaxZoomFactor);
            zoom = MIN(zoom, 4.0);
            if (zoom > 1.0) d.videoZoomFactor = zoom;
        }
    }
    [d unlockForConfiguration];

    CGFloat zoomNow = d.videoZoomFactor;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (macro) {
            [self showStatus:@"凑近会自动切微距镜头（点画面可对焦）"];
        } else if (zoomNow > 1.01) {
            [self showStatus:[NSString stringWithFormat:@"已自动放大 %.1fx，离远一点更清楚（点画面可对焦）", zoomNow]];
        } else {
            [self showStatus:@"对准二维码 / 条形码（点画面可对焦）"];
        }
    });
}

- (void)handleTapToFocus:(UITapGestureRecognizer *)g {
    AVCaptureDevice *d = self.device;
    if (!d || !self.previewLayer) return;
    CGPoint viewPoint = [g locationInView:self.previewView];
    CGPoint devPoint = [self.previewLayer captureDevicePointOfInterestForPoint:viewPoint];
    dispatch_async(self.sessionQueue, ^{
        NSError *err = nil;
        if (![d lockForConfiguration:&err]) return;
        if (d.isFocusPointOfInterestSupported) d.focusPointOfInterest = devPoint;
        if ([d isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) d.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        else if ([d isFocusModeSupported:AVCaptureFocusModeAutoFocus]) d.focusMode = AVCaptureFocusModeAutoFocus;
        if (d.isExposurePointOfInterestSupported) d.exposurePointOfInterest = devPoint;
        if ([d isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) d.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        [d unlockForConfiguration];
    });

    // 画个对焦框
    self.focusBox.center = viewPoint;
    self.focusBox.transform = CGAffineTransformMakeScale(1.4, 1.4);
    self.focusBox.alpha = 1;
    [UIView animateWithDuration:0.25 animations:^{
        self.focusBox.transform = CGAffineTransformIdentity;
    } completion:^(BOOL done) {
        [UIView animateWithDuration:0.3 delay:0.6 options:0 animations:^{ self.focusBox.alpha = 0; } completion:nil];
    }];
}

- (void)startSession {
    if (!self.session) return;
    dispatch_async(self.sessionQueue, ^{ if (!self.session.isRunning) [self.session startRunning]; });
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)objects fromConnection:(AVCaptureConnection *)connection {
    for (AVMetadataObject *obj in objects) {
        if (![obj isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) continue;
        NSString *value = ((AVMetadataMachineReadableCodeObject *)obj).stringValue;
        if (value.length == 0) continue;

        // 同一个码一直怼着镜头时，3 秒内不重复记录
        if ([value isEqualToString:self.lastValue] && self.lastTime && -[self.lastTime timeIntervalSinceNow] < 3) continue;
        self.lastValue = value;
        self.lastTime = [NSDate date];

        [self appendResult:value type:obj.type];
    }
}

#pragma mark 结果

- (NSString *)prettyType:(AVMetadataObjectType)t {
    NSDictionary *m = @{AVMetadataObjectTypeQRCode: @"QR", AVMetadataObjectTypeEAN13Code: @"EAN-13",
                        AVMetadataObjectTypeEAN8Code: @"EAN-8", AVMetadataObjectTypeUPCECode: @"UPC-E",
                        AVMetadataObjectTypeCode128Code: @"Code128", AVMetadataObjectTypeCode39Code: @"Code39",
                        AVMetadataObjectTypeCode39Mod43Code: @"Code39", AVMetadataObjectTypeCode93Code: @"Code93",
                        AVMetadataObjectTypePDF417Code: @"PDF417", AVMetadataObjectTypeAztecCode: @"Aztec",
                        AVMetadataObjectTypeDataMatrixCode: @"DataMatrix", AVMetadataObjectTypeITF14Code: @"ITF-14",
                        AVMetadataObjectTypeInterleaved2of5Code: @"ITF"};
    return m[t] ?: t;
}

- (void)appendResult:(NSString *)value type:(AVMetadataObjectType)type {
    NSDateFormatter *f = [NSDateFormatter new];
    f.dateFormat = @"HH:mm:ss";
    NSString *line = [NSString stringWithFormat:@"[%@ %@] %@", [f stringFromDate:[NSDate date]], [self prettyType:type], value];

    NSString *old = self.textView.text ?: @"";
    self.textView.text = old.length ? [old stringByAppendingFormat:@"\n%@", line] : line;
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 0)];
    [self saveText];

    [self showStatus:[NSString stringWithFormat:@"已识别：%@", value]];
    [self updateOpenButtonFor:value];
    [[UINotificationFeedbackGenerator new] notificationOccurred:UINotificationFeedbackTypeSuccess];

    // 预览闪一下绿框
    self.previewView.layer.borderColor = [UIColor systemGreenColor].CGColor;
    self.previewView.layer.borderWidth = 4;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.previewView.layer.borderWidth = 0;
    });
}

- (void)showStatus:(NSString *)s { self.statusLabel.text = s; }

- (void)saveText {
    [[NSUserDefaults standardUserDefaults] setObject:self.textView.text forKey:kSavedTextKey];
}

- (void)clearText {
    self.textView.text = @"";
    self.lastValue = nil;
    [self updateOpenButtonFor:@""];
    [self saveText];
    [self showStatus:@"已清空，对准二维码 / 条形码"];
}

- (void)copyText {
    [UIPasteboard generalPasteboard].string = self.textView.text;
    [self showStatus:@"已复制到剪贴板"];
}

- (void)updateOpenButtonFor:(NSString *)value {
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURL *url = [NSURL URLWithString:trimmed];
    NSString *scheme = url.scheme.lowercaseString;
    BOOL isWeb = url.host.length > 0 && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]);
    self.pendingURL = isWeb ? url : nil;
    self.openButton.hidden = !isWeb;
}

- (void)openLink {
    NSURL *url = self.pendingURL;
    if (!url) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"打开这个链接？"
                                                               message:url.absoluteString
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)dismissKeyboard {
    [self.textView resignFirstResponder];
    [self saveText];
}

@end

#pragma mark - App

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[ScannerViewController new]];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

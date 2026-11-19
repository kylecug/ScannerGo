#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>

#pragma mark - N 单号 → 二维码

// 文字识别出来的东西里挑 "N + 一串数字" 的单号（比如面单右上角 N26111500026813）。
// OCR 常把 0 认成 O、1 认成 I/l，N 后面这部分顺手纠一下；纠完还有字母就不要（N06E1D... 这种直接排除）。
static NSString *ExtractNNumber(NSString *raw) {
    NSString *s = [[raw componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@""];
    if (s.length < 2 || [s characterAtIndex:0] != 'N') return nil;
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger i = 1; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == 'O' || c == 'o' || c == 'D') c = '0';
        else if (c == 'I' || c == 'l' || c == '|') c = '1';
        if (c < '0' || c > '9') return nil;
        [digits appendFormat:@"%C", c];
    }
    if (digits.length < 8) return nil;   // 太短的大概率是误识别
    return [@"N" stringByAppendingString:digits];
}

static UIImage *MakeQRImage(NSString *text, CGFloat scale) {
    CIFilter *f = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [f setValue:[text dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [f setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *ci = [f.outputImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    if (!ci) return nil;
    static CIContext *ctx; static dispatch_once_t once;
    dispatch_once(&once, ^{ ctx = [CIContext contextWithOptions:nil]; });
    CGImageRef cg = [ctx createCGImage:ci fromRect:ci.extent];
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return img;
}

#pragma mark - 全屏二维码（给别的机器扫）

@interface QRViewController : UIViewController
@property (nonatomic, copy) NSString *text;
@property (nonatomic) CGFloat oldBrightness;
@end

@implementation QRViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    UIImageView *iv = [[UIImageView alloc] initWithImage:MakeQRImage(self.text, 20)];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.layer.magnificationFilter = kCAFilterNearest;
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:iv];

    UILabel *l = [UILabel new];
    l.text = self.text;
    l.textColor = [UIColor blackColor];
    l.font = [UIFont monospacedSystemFontOfSize:22 weight:UIFontWeightSemibold];
    l.textAlignment = NSTextAlignmentCenter;
    l.adjustsFontSizeToFitWidth = YES;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:l];

    UILabel *hint = [UILabel new];
    hint.text = @"点任意处关闭";
    hint.textColor = [UIColor grayColor];
    hint.font = [UIFont systemFontOfSize:14];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hint];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [iv.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:g.centerYAnchor constant:-20],
        [iv.widthAnchor constraintEqualToAnchor:iv.heightAnchor],
        [iv.widthAnchor constraintLessThanOrEqualToAnchor:g.widthAnchor multiplier:0.85],
        [iv.heightAnchor constraintLessThanOrEqualToAnchor:g.heightAnchor multiplier:0.7],
        [l.topAnchor constraintEqualToAnchor:iv.bottomAnchor constant:16],
        [l.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [l.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [hint.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [hint.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-16],
    ]];
    NSLayoutConstraint *big = [iv.widthAnchor constraintEqualToAnchor:g.widthAnchor multiplier:0.85];
    big.priority = UILayoutPriorityDefaultHigh;
    big.active = YES;

    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)]];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 屏幕调到最亮，扫枪 / 别的手机更好扫
    self.oldBrightness = [UIScreen mainScreen].brightness;
    [UIScreen mainScreen].brightness = 1.0;
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [UIScreen mainScreen].brightness = self.oldBrightness;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - 扫码页面

@interface ScannerViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
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
// 文字识别（N 单号 → 二维码）
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) VNRecognizeTextRequest *textRequest;
@property (atomic) CGImagePropertyOrientation ocrOrientation;
@property (nonatomic) CFTimeInterval lastOCRTime;        // 只在 videoQueue 上用
@property (nonatomic, copy) NSString *ocrCandidate;      // 只在 videoQueue 上用：连续两次认出同一串才算数
@property (nonatomic, copy) NSString *currentNNumber;
@property (nonatomic, strong) NSDate *lastNNumberTime;
@property (nonatomic, strong) UIControl *qrCard;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UILabel *qrLabel;
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

    // 左上角：识别到 N 单号后生成的二维码，点一下全屏放大
    self.qrCard = [UIControl new];
    self.qrCard.backgroundColor = [UIColor whiteColor];
    self.qrCard.layer.cornerRadius = 10;
    self.qrCard.hidden = YES;
    self.qrCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.qrCard addTarget:self action:@selector(showBigQR) forControlEvents:UIControlEventTouchUpInside];
    [self.previewView addSubview:self.qrCard];

    self.qrImageView = [UIImageView new];
    self.qrImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.qrImageView.layer.magnificationFilter = kCAFilterNearest;
    self.qrImageView.userInteractionEnabled = NO;
    self.qrImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.qrCard addSubview:self.qrImageView];

    self.qrLabel = [UILabel new];
    self.qrLabel.textColor = [UIColor blackColor];
    self.qrLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
    self.qrLabel.textAlignment = NSTextAlignmentCenter;
    self.qrLabel.adjustsFontSizeToFitWidth = YES;
    self.qrLabel.minimumScaleFactor = 0.6;
    self.qrLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.qrCard addSubview:self.qrLabel];

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

        [self.qrCard.topAnchor constraintEqualToAnchor:self.previewView.topAnchor constant:12],
        [self.qrCard.leadingAnchor constraintEqualToAnchor:self.previewView.leadingAnchor constant:12],
        [self.qrCard.widthAnchor constraintEqualToConstant:132],
        [self.qrImageView.topAnchor constraintEqualToAnchor:self.qrCard.topAnchor constant:8],
        [self.qrImageView.leadingAnchor constraintEqualToAnchor:self.qrCard.leadingAnchor constant:8],
        [self.qrImageView.trailingAnchor constraintEqualToAnchor:self.qrCard.trailingAnchor constant:-8],
        [self.qrImageView.heightAnchor constraintEqualToAnchor:self.qrImageView.widthAnchor],
        [self.qrLabel.topAnchor constraintEqualToAnchor:self.qrImageView.bottomAnchor constant:4],
        [self.qrLabel.leadingAnchor constraintEqualToAnchor:self.qrCard.leadingAnchor constant:6],
        [self.qrLabel.trailingAnchor constraintEqualToAnchor:self.qrCard.trailingAnchor constant:-6],
        [self.qrLabel.bottomAnchor constraintEqualToAnchor:self.qrCard.bottomAnchor constant:-6],

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
    [self updateOCROrientation];
}

// 后置摄像头原始画面是横的（Home 键在右），按当前界面方向告诉 Vision 怎么转
- (void)updateOCROrientation {
    UIInterfaceOrientation o = self.view.window.windowScene.interfaceOrientation;
    CGImagePropertyOrientation r = kCGImagePropertyOrientationRight;
    if (o == UIInterfaceOrientationLandscapeRight) r = kCGImagePropertyOrientationUp;
    else if (o == UIInterfaceOrientationLandscapeLeft) r = kCGImagePropertyOrientationDown;
    else if (o == UIInterfaceOrientationPortraitUpsideDown) r = kCGImagePropertyOrientationLeft;
    self.ocrOrientation = r;
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

    // 视频帧输出：拿来做文字识别，找 N 开头的单号
    AVCaptureVideoDataOutput *video = [AVCaptureVideoDataOutput new];
    video.alwaysDiscardsLateVideoFrames = YES;
    video.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    if ([session canAddOutput:video]) {
        self.videoQueue = dispatch_queue_create("scanner.ocr", DISPATCH_QUEUE_SERIAL);
        [video setSampleBufferDelegate:self queue:self.videoQueue];
        [session addOutput:video];
        VNRecognizeTextRequest *req = [VNRecognizeTextRequest new];
        req.recognitionLevel = VNRequestTextRecognitionLevelAccurate; // 数字要准，慢点无所谓
        req.usesLanguageCorrection = NO;
        req.minimumTextHeight = 0.02;
        self.textRequest = req;
        self.ocrOrientation = kCGImagePropertyOrientationRight;
    }

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

#pragma mark 文字识别

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // 大概每 0.4 秒认一次，省电；慢的帧系统会自己丢
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.lastOCRTime < 0.4) return;
    self.lastOCRTime = now;

    CVPixelBufferRef px = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!px || !self.textRequest) return;
    VNImageRequestHandler *h = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:px orientation:self.ocrOrientation options:@{}];
    if (![h performRequests:@[self.textRequest] error:nil]) return;

    // 同一帧里有多个（面单右上角 + 侧边 Sender Ref 一般是同一个号）就挑最长的
    NSString *best = nil;
    for (VNRecognizedTextObservation *obs in self.textRequest.results) {
        for (VNRecognizedText *t in [obs topCandidates:3]) {
            NSString *n = ExtractNNumber(t.string);
            if (n && n.length > best.length) best = n;
            if (n) break;
        }
    }
    if (!best) { self.ocrCandidate = nil; return; }

    // 连续两次认出一模一样的才采用，防止看错一两位
    if (![best isEqualToString:self.ocrCandidate]) { self.ocrCandidate = best; return; }
    dispatch_async(dispatch_get_main_queue(), ^{ [self foundNNumber:best]; });
}

- (void)foundNNumber:(NSString *)n {
    // 同一个号一直对着时，10 秒内不重复记录
    if ([n isEqualToString:self.currentNNumber] && self.lastNNumberTime && -[self.lastNNumberTime timeIntervalSinceNow] < 10) return;
    BOOL changed = ![n isEqualToString:self.currentNNumber];
    self.currentNNumber = n;
    self.lastNNumberTime = [NSDate date];

    if (changed) {
        self.qrImageView.image = MakeQRImage(n, 10);
        self.qrLabel.text = n;
        self.qrCard.hidden = NO;
    }
    [self appendResult:n type:@"文字→QR"];
    [self showStatus:[NSString stringWithFormat:@"单号 %@ 已转成二维码，点左上角放大", n]];
}

- (void)showBigQR {
    if (!self.currentNNumber) return;
    QRViewController *vc = [QRViewController new];
    vc.text = self.currentNNumber;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
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
    self.currentNNumber = nil;
    self.qrCard.hidden = YES;
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

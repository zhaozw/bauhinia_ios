
#import "MessageInputView.h"
#import "NSString+JSMessagesView.h"
#import "UIImage+JSMessagesView.h"

#import "FBShimmeringView.h"
#import "IMService.h"

#define SEND_BUTTON_WIDTH 64.0f

#define  CANCEL_SEND_DISTANCE  50.0f

#define INPUT_HEIGHT 46.0f

@interface MessageInputView ()

- (void)setup;
- (void)setupTextView;

@end



@implementation MessageInputView

#pragma mark - Initialization
- (id)initWithFrame:(CGRect)frame andDelegate:(id < MessageInputRecordDelegate>) dleg
{
    self = [super initWithFrame:frame];
    if(self) {
        self.delegate = dleg;
        [self setup];
    }
    return self;
}

- (void)dealloc
{
    self.textView = nil;
    self.sendButton = nil;
}

#pragma mark - Setup
- (void)setup
{
    [self setUserInteractionEnabled:YES];
    
    UIImageView *bkview = [[UIImageView alloc] initWithFrame:self.frame];
    [bkview setFrame:CGRectMake(0, 0, 320, 44)];
    UIImage *img = [UIImage imageNamed:@"input-bar-flat.png"];
    UIImage *stretchImg = [img stretchableImageWithLeftCapWidth:1 topCapHeight:5];
    [bkview setImage:stretchImg];
    [self addSubview:bkview];
    
    self.backgroundColor = [UIColor whiteColor];
    self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin);
    self.opaque = YES;
    self.userInteractionEnabled = YES;
    [self setupTextView];
    
    {
        self.sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        CGRect frame = self.frame;
        double x = frame.size.width - 56.0;
        double y = (frame.size.height - 26.0)/2;
        double width = 60.0;
        double height = 26.0;
        self.sendButton.enabled = NO;
        self.sendButton.frame = CGRectMake(x, y, width, height);
        self.sendButton.hidden = YES;
        NSString *title = @"发送";
        [self.sendButton setTitle:title forState:UIControlStateNormal];
        [self.sendButton setTitle:title forState:UIControlStateHighlighted];
        [self.sendButton setTitle:title forState:UIControlStateDisabled];
        self.sendButton.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin);
        
        [self addSubview:self.sendButton];
    }

    {
        self.recordButton = [[UILabel alloc] init];
        
        CGRect frame = self.frame;
        double x = frame.size.width - 46.0;
        double y = (frame.size.height - 26.0)/2;
        double width = 60.0;
        double height = 26.0;

        self.recordButton.enabled = NO;
        self.recordButton.frame = CGRectMake(x, y, width, height);
        
        NSString *title = @"录音";
        [self.recordButton setText:title];
        [self.recordButton setTextColor:RGBACOLOR(60, 140, 246, 1)];
        [self.recordButton setBackgroundColor:[UIColor clearColor]];
        self.recordButton.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin);
        
        [self addSubview:self.recordButton];
    }

    {
        // set up the image and button frame
		UIImage* image = [UIImage imageNamed:@"PhotoIcon"];
        CGRect frame = self.frame;
		CGRect buttonFrame = CGRectMake(8, 0, image.size.width, image.size.height);
		CGFloat yHeight = (frame.size.height - buttonFrame.size.height) / 2.0f;
		buttonFrame.origin.y = yHeight;
		
		// make the button
		self.mediaButton = [[UIButton alloc] initWithFrame:buttonFrame];
		[self.mediaButton setBackgroundImage:image forState:UIControlStateNormal];
		[self addSubview:self.mediaButton];
    }

    {
        CGRect frame = self.frame;
        CGRect viewFrame = self.frame;
        viewFrame = CGRectMake(0, 0, frame.size.width, frame.size.height);
        self.recordingView = [[UIView alloc] initWithFrame:viewFrame];
        [self.recordingView setBackgroundColor:[UIColor clearColor]];
        
        CGRect labelFrame = CGRectMake(100, 0, 160, 26);
        labelFrame.origin.x = (frame.size.width - labelFrame.size.width)/2;
        labelFrame.origin.y = (frame.size.height - labelFrame.size.height)/2;
        self.slipLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [self.slipLabel setTextAlignment: NSTextAlignmentCenter];
        [self.slipLabel setFont: [UIFont systemFontOfSize:19.0f]];
        [self.slipLabel setBackgroundColor:[UIColor clearColor]];
        self.slipLabel.text = @"滑动取消 <";
        [self.recordingView addSubview: self.slipLabel];
        
        FBShimmeringView *shimmeringView = [[FBShimmeringView alloc] initWithFrame:self.slipLabel.bounds];
        shimmeringView.contentView = self.slipLabel;
        shimmeringView.shimmering = YES;
       
        [self.recordingView addSubview:shimmeringView];
        
        CGRect maskFrame = CGRectMake(0, 0, 70, frame.size.height);
        UIImage *img = [UIImage imageNamed:@"input-bar-flat.png"];
        UIImage *stretchImg = [img stretchableImageWithLeftCapWidth:1 topCapHeight:5];
       UIImageView *maskView = [[UIImageView alloc] initWithFrame:maskFrame];
        [maskView setImage:stretchImg];
        [self.recordingView addSubview:maskView];
        
        labelFrame = CGRectMake(40, 0, 60, 26);
        labelFrame.origin.y = (frame.size.height - labelFrame.size.height)/2;
        [self.timerLabel setBackgroundColor:[UIColor grayColor]];
        self.timerLabel = [[UILabel alloc] initWithFrame:labelFrame];
        [self.recordingView addSubview:self.timerLabel];

        
        NSArray *ary = @[[UIImage imageNamed:@"MicRecRed"],[UIImage imageNamed:@"MicEmpty"]];
        CGRect recordAFrame = CGRectMake(13, 0, 18, 29);
        recordAFrame.origin.y = (frame.size.height - recordAFrame.size.height)/2;
        
        self.recordAnimationView = [[UIImageView alloc] initWithFrame: recordAFrame];
        self.recordAnimationView.animationImages = ary;
        self.recordAnimationView.animationDuration = 0.75;
        [self.recordAnimationView startAnimating];
        [self.recordingView addSubview:self.recordAnimationView];
       
        [self addSubview:self.recordingView];
        self.recordingView.hidden = YES;

    }
}

- (void)slipLabelFrame:(double)x {
    CGRect frame = self.frame;
    CGRect labelFrame = CGRectMake(100, 0, 160, 26);
    labelFrame.origin.y = (frame.size.height - labelFrame.size.height)/2;
    labelFrame.origin.x += x;
    self.slipLabel.frame = labelFrame;
}

- (void)resetLabelFrame {
    CGRect frame = self.frame;
    CGRect labelFrame = CGRectMake(100, 0, 160, 26);
    labelFrame.origin.y = (frame.size.height - labelFrame.size.height)/2;
    self.slipLabel.frame = labelFrame;
}

- (void)setupTextView
{
    CGFloat width = self.frame.size.width - SEND_BUTTON_WIDTH - 26;
    CGFloat height = [MessageInputView textViewLineHeight];
    CGRect frame = self.frame;
    
    double x = 40.0;
    double y = (frame.size.height - height)/2;

    
    self.textView = [[UITextView  alloc] initWithFrame:CGRectMake(x, y, width, height)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.textView.backgroundColor = [UIColor clearColor];
    [self.textView setFont:[UIFont systemFontOfSize:16]];
    self.textView.layer.borderColor = [[UIColor colorWithWhite:.8 alpha:1.0] CGColor];
    self.textView.layer.borderWidth = 0.65f;
    self.textView.layer.cornerRadius = 6.0f;


    [self addSubview:self.textView];
}

- (void) setRecordShowing{
    self.textView.hidden = YES;
    self.mediaButton.hidden = YES;
    self.recordingView.hidden = NO;
    [self resetLabelFrame];
    self.timerLabel.text = @"00:00";
    [self.recordAnimationView startAnimating];
}

- (void) setNomarlShowing{
    [self.textView setText:nil];
    [self.textView resignFirstResponder];
    self.sendButton.enabled = NO;
    self.sendButton.hidden = YES;
    self.recordButton.hidden = NO;
    self.recordButton.enabled = ([[IMService instance] connectState] == STATE_CONNECTED);
}

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    NSLog(@"touchBegan");
    UITouch *touch      = [touches anyObject];
    
    if(touch.tapCount == 1){
        CGPoint superPoint  = [touch locationInView:self];
        if(CGRectContainsPoint(self.recordButton.frame,superPoint)){
            
            self.lastPoint = superPoint;
            
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(recordStart)]) {
                [self.delegate recordStart];
            }
        }
    }
    
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    NSLog(@"touchmove");
    UITouch *touch      = [touches anyObject];
    if (touch.tapCount == 1) {
        CGPoint newPoint = [touch locationInView:self];
        CGFloat xmove = newPoint.x - self.lastPoint.x;
        NSLog(@"xmove:%f",xmove);
        if (xmove < 0 && abs(xmove) > CANCEL_SEND_DISTANCE) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(recordCancel:)]){
                [self.delegate recordCancel:xmove];
            }
        }
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    NSLog(@"touchEnded");
    if (self.delegate && [self.delegate respondsToSelector:@selector(recordEnd)]) {

        [self.delegate recordEnd];
    }
}


#pragma mark - Message input view
+ (CGFloat)textViewLineHeight
{
    return 30.0f; // for fontSize 16.0f
}

+ (CGFloat)maxLines
{
    return 4.0f;
}

+ (CGFloat)maxHeight
{
    return ([MessageInputView maxLines] + 1.0f) * [MessageInputView textViewLineHeight];
}

@end
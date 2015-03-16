#import "BubbleView.h"
#import "NSString+JSMessagesView.h"
#import "UIImage+JSMessagesView.h"

CGFloat const kJSAvatarSize = 50.0f;

@interface BubbleView()

+ (UIImage *)bubbleImageTypeIncoming;
+ (UIImage *)bubbleImageTypeOutgoing;

@end

@implementation BubbleView

#pragma mark - Initialization
- (id)initWithFrame:(CGRect)frame withType:(BubbleMessageType)type
{
    self = [super initWithFrame:frame];
    if(self) {
        
        self.type = type;
        
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        
        CGRect bubbleFrame = [self bubbleFrame];
        self.bubleBKView = [[UIImageView alloc] initWithFrame:bubbleFrame];
        [self.bubleBKView setImage:(self.selectedToShowCopyMenu) ? [self bubbleImageHighlighted] : [self bubbleImage]];
        [self addSubview:self.bubleBKView];
        
        self.msgSendErrorBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
        [self.msgSendErrorBtn setImage:[UIImage imageNamed:@"MessageSendError"] forState:UIControlStateNormal];
        [self.msgSendErrorBtn setImage:[UIImage imageNamed:@"MessageSendError"]  forState: UIControlStateHighlighted];
        self.msgSendErrorBtn.hidden = YES;
        [self addSubview:self.msgSendErrorBtn];
        
        self.msgSignImgView = [[UIImageView alloc] init];
        [self addSubview:self.msgSignImgView];
        
    }
    return self;
}

#pragma mark - Setters

- (void) setMsgStateType:(BubbleMessageReceiveStateType)type{
    _msgStateType = type;
    
    if (self.type == BubbleMessageTypeOutgoing) {
        UIImage *msgSignImg = nil;
        switch (_msgStateType) {
            case BubbleMessageReceiveStateNone:
            {
                msgSignImg = [UIImage imageNamed:@"CheckDoubleLight"];
            }
                break;
            case BubbleMessageReceiveStateClient:
            {
                msgSignImg = [UIImage imageNamed:@"CheckDoubleGreen"];
            }
                break;
            case BubbleMessageReceiveStateServer:
            {
                msgSignImg = [UIImage imageNamed:@"CheckSingleGreen"];
            }
                break;
            default:
                break;
        }
        
        CGRect bubbleFrame = [self bubbleFrame];
        
        CGFloat imgX = bubbleFrame.origin.x + bubbleFrame.size.width - msgSignImg.size.width;
        imgX = self.type == BubbleMessageTypeOutgoing ?(imgX - 15):(imgX - 5);
        
        CGRect msgStateSignRect = CGRectMake(imgX, bubbleFrame.size.height -  kPaddingBottom - msgSignImg.size.height, msgSignImg.size.width , msgSignImg.size.height);

        [self.msgSignImgView setFrame:msgStateSignRect];
        [self.msgSignImgView setImage:msgSignImg];
    }
}

- (void)setSelectedToShowCopyMenu:(BOOL)isSelected{
    _selectedToShowCopyMenu = isSelected;
    [self setNeedsDisplay];
}

#pragma mark - Drawing
- (CGRect)bubbleFrame{
    NSLog(@"act对象消息");
    return CGRectMake(0, 0, 0, 0);
}

- (UIImage *)bubbleImage{
    return [BubbleView bubbleImageForType:self.type];
}

- (UIImage *)bubbleImageHighlighted{
    return (self.type == BubbleMessageTypeIncoming) ? [UIImage bubbleDefaultIncomingSelected] : [UIImage bubbleDefaultOutgoingSelected];
}

-(void) showSendErrorBtn:(BOOL)show{
    if (self.type == BubbleMessageTypeOutgoing) {
        [self.msgSendErrorBtn setHidden:!show];
        
        CGRect bubbleFrame = [self bubbleFrame];
        CGFloat imgX = bubbleFrame.origin.x;
        CGRect rect = self.msgSendErrorBtn.frame;
        rect.origin.x = imgX - self.msgSendErrorBtn.frame.size.width + 2;
        rect.origin.y = bubbleFrame.origin.y + bubbleFrame.size.height  - self.msgSendErrorBtn.frame.size.height - kMarginBottom;
        [self.msgSendErrorBtn setFrame:rect];
        [self bringSubviewToFront:self.msgSendErrorBtn];
    }

}

#pragma mark - Bubble view
+ (UIImage *)bubbleImageForType:(BubbleMessageType)aType
{
    switch (aType) {
        case BubbleMessageTypeIncoming:
            return [self bubbleImageTypeIncoming];
            
        case BubbleMessageTypeOutgoing:
            return [self bubbleImageTypeOutgoing];
            
        default:
            return nil;
    }
}

+ (UIImage *)bubbleImageTypeIncoming{
    return [UIImage bubbleDefaultIncoming];
}

+ (UIImage *)bubbleImageTypeOutgoing{
    return [UIImage bubbleDefaultOutgoing];
}

+ (UIFont *)font{
    return [UIFont systemFontOfSize:14.0f];
}

+ (CGSize)textSizeForText:(NSString *)txt{
    CGFloat width = [UIScreen mainScreen].applicationFrame.size.width * 0.75f;
    CGFloat height = MAX([BubbleView numberOfLinesForMessage:txt],
                         [txt numberOfLines]) *  30.0f; // for fontSize 16.0f;
    
    return [txt sizeWithFont:[BubbleView font]
           constrainedToSize:CGSizeMake(width - kJSAvatarSize, height + kJSAvatarSize)
               lineBreakMode:NSLineBreakByWordWrapping];
}

+ (CGSize)bubbleSizeForText:(NSString *)txt
{
	CGSize textSize = [BubbleView textSizeForText:txt];
	return CGSizeMake(textSize.width + kBubblePaddingRight,
                      textSize.height + kPaddingTop + kPaddingBottom);
}

+ (CGSize)bubbleSizeForImage:(UIImage *)image{
    CGSize imageSize = [BubbleView imageSizeForImage];
	return CGSizeMake(imageSize.width,
                      imageSize.height);
}

+ (CGSize)imageSizeForImage{
    CGFloat width = [UIScreen mainScreen].applicationFrame.size.width * 0.75f;
    CGFloat height = 130.f;
    
    return CGSizeMake(width - kJSAvatarSize, height + kJSAvatarSize);
    
}

//+ (CGFloat)cellHeightForText:(NSString *)txt
//{
//    return [BubbleView bubbleSizeForText:txt].height + kMarginTop + kMarginBottom;
//}


+ (int)maxCharactersPerLine
{
    return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? 34 : 109;
}

+ (int)numberOfLinesForMessage:(NSString *)txt
{
    return (txt.length / [BubbleView maxCharactersPerLine]) + 1;
}

@end

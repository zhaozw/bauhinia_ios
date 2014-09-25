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
- (id)initWithFrame:(CGRect)rect
{
    self = [super initWithFrame:rect];
    if(self) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

#pragma mark - Setters
- (void)setType:(BubbleMessageType)newType
{
    _type = newType;
    [self setNeedsDisplay];
}

- (void) setMsgStateType:(BubbleMessageReceiveStateType)type{
    _msgStateType = type;
    [self setNeedsDisplay];
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

-(void) drawMsgStateSign:(CGRect) frame{
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
        
        CGRect msgStateSignRect = CGRectMake(imgX, frame.size.height -  kPaddingBottom - msgSignImg.size.height, msgSignImg.size.width , msgSignImg.size.height);
        
        [msgSignImg drawInRect:msgStateSignRect];
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

+ (CGFloat)cellHeightForText:(NSString *)txt
{
    return [BubbleView bubbleSizeForText:txt].height + kMarginTop + kMarginBottom;
}

+ (CGFloat)cellHeightForImage:(UIImage *)image{
    return [BubbleView bubbleSizeForImage:image].height + kMarginTop + kMarginBottom;
}

+ (int)maxCharactersPerLine
{
    return ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) ? 34 : 109;
}

+ (int)numberOfLinesForMessage:(NSString *)txt
{
    return (txt.length / [BubbleView maxCharactersPerLine]) + 1;
}

@end
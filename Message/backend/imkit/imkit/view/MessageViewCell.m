


#import "MessageViewCell.h"
#import "UIImage+JSMessagesView.h"
#import "MessageTextView.h"
#import "MessageImageView.h"
#import "MessageAudioView.h"

@implementation MessageViewCell

#pragma mark - Setup
- (void)cleanBK
{
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.accessoryView = nil;
    
    self.imageView.image = nil;
    self.imageView.hidden = YES;
    self.textLabel.text = nil;
    self.textLabel.hidden = YES;
    self.detailTextLabel.text = nil;
    self.detailTextLabel.hidden = YES;
    
    [self.bubbleView removeFromSuperview];
    self.bubbleView.bcTextView = nil;
    self.bubbleView = nil;
    
}


-(id)initWithMessage:(IMessage *)message withBubbleMessageType: (BubbleMessageType)bubbleMessageType reuseIdentifier:(NSString *)reuseIdentifier{
    self =  [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self initializeWithMessage:message withBubbleMessageType:bubbleMessageType];
    }
    return self;
}

-(void)initializeWithMessage:(IMessage *)message withBubbleMessageType: (BubbleMessageType)bubbleMessageType{
    [self cleanBK];
    
    CGFloat bubbleY = 0.0f;
    CGFloat bubbleX = 0.0f;
    
    CGFloat offsetX = 0.0f;
    
    CGRect frame = CGRectMake(bubbleX - offsetX,
                              bubbleY,
                              self.contentView.frame.size.width - bubbleX,
                              self.contentView.frame.size.height);
    
    BubbleMessageReceiveStateType receiveStateType;
    if(message.isACK){
        if (message.isPeerACK) {
            receiveStateType =  BubbleMessageReceiveStateClient;
        }else{
            receiveStateType =  BubbleMessageReceiveStateServer;
        }
    }else{
        receiveStateType =  BubbleMessageReceiveStateNone;
    }
    
    switch (message.content.type) {
        case MESSAGE_AUDIO:
        {
            MessageAudioView *audioView = [[MessageAudioView alloc] initWithFrame:frame withType:bubbleMessageType];
            [audioView initializeWithMsg:message withMsgStateType:receiveStateType];
            self.bubbleView = audioView;
        }
            break;
        case MESSAGE_TEXT:
        {
            MessageTextView *textView = [[MessageTextView alloc] initWithFrame:frame withType:bubbleMessageType];
            [textView initializeWithMsg:message withMsgStateType:receiveStateType];
            self.bubbleView = textView;
        }
            break;
        case MESSAGE_IMAGE:
        {
            MessageImageView *imageView = [[MessageImageView alloc] initWithFrame:frame withType:bubbleMessageType];
            [imageView initializeWithMsg:message withMsgStateType:receiveStateType];
            self.bubbleView = imageView;
        }
            break;
        default:
            self.bubbleView = nil;
            break;
    }
    
    if (message.flags&MESSAGE_FLAG_FAILURE) {
        [self.bubbleView showSendErrorBtn:YES];
    }else{
        [self.bubbleView showSendErrorBtn:NO];
    }
    
    if (self.bubbleView != nil) {
        [self.contentView addSubview:self.bubbleView];
        [self.contentView sendSubviewToBack:self.bubbleView];
        [self setBackgroundColor:[UIColor clearColor]];
    }
}

#pragma mark - Touch events
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
}

@end
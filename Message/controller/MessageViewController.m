//
//  MessageViewController
//  Created by daozhu on 14-6-16.
//  Copyright (c) 2014年 daozhu. All rights reserved.
//

#import "MessageViewController.h"
#import "IMessage.h"
#import "IMService.h"
#import "UserPresent.h"
#import "MessageDB.h"
#import "ConversationHeadButtonView.h"
#import "MessageTableSectionHeaderView.h"
#import "MessageShowThePotraitViewController.h"
#import "AppDelegate.h"
#import "UserDB.h"
#import "NSString+JSMessagesView.h"
#import "PeerMessageDB.h"
#import "UserPresent.h"


#define navBarHeadButtonSize 35



@interface MessageViewController () <JSMessagesViewDelegate, JSMessagesViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate>


@property (strong, nonatomic) NSMutableArray *messageArray;
@property (nonatomic,strong) UIImage *willSendImage;
@property (strong, nonatomic) NSMutableArray *timestamps;
@end

@implementation MessageViewController


-(id) initWithRemoteUser:(IMUser*) rmtUser{
    
    if (self = [super init]) {
        self.remoteUser = rmtUser;
        self.curUser  =  [[UserDB instance] loadUser: [UserPresent instance].uid];
    }
    return self;
}


- (void)loadView{
    [super loadView];
    
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.delegate = self;
    self.dataSource = self;
    [self setNormalNavigationButtons];
    
    self.navigationBarButtonsView = [[[NSBundle mainBundle]loadNibNamed:@"ConversationHeadButtonView" owner:self options:nil] lastObject];
    self.navigationBarButtonsView.center = self.navigationController.navigationBar.center;
    if ([self.curUser.contact.contactName length] == 0) {
        [self.navigationBarButtonsView.nameLabel setText:@"消息"];
    }else{
        [self.navigationBarButtonsView.nameLabel setText:self.curUser.contact.contactName];
    }
    self.navigationItem.titleView = self.navigationBarButtonsView;
    
    [[self sendButton] setUserInteractionEnabled: NO];
    
    [self processConversationData];
    
    
    [[IMService instance] addMessageObserver:self];
    
    
}

-(void) viewDidAppear:(BOOL)animated{

    [[IMService instance] subscribeState:self.remoteUser.uid];
 
}

-(void) viewDidDisappear:(BOOL)animated{
    
   [[IMService instance] unsubscribeState:self.remoteUser.uid];
}

#pragma mark - MessageObserver

-(void)onPeerMessage:(IMMessage*)im{
    [JSMessageSoundEffect playMessageReceivedSound];
    NSLog(@"receive msg:%@",im);
    
    IMessage *m = [[IMessage alloc] init];
    m.sender = im.sender;
    m.receiver = im.receiver;
    m.msgLocalID = im.msgLocalID;
    MessageContent *content = [[MessageContent alloc] init];
    content.raw = im.content;
    m.content = content;
    m.timestamp = time(NULL);
    
    [self addMessageToTheTableView: m];
    
    [self scrollToBottomAnimated:YES];
}

//服务器ack
-(void)onPeerMessageACK:(int)msgLocalID uid:(int64_t)uid{
    IMessage *msg = [self getImMessageById:msgLocalID];
    msg.flags = msg.flags|MESSAGE_FLAG_ACK;
    [self reloadMessage:msgLocalID];
}

//接受方ack
-(void)onPeerMessageRemoteACK:(int)msgLocalID uid:(int64_t)uid{
    IMessage *msg = [self getImMessageById:msgLocalID];
    msg.flags = msg.flags|MESSAGE_FLAG_PEER_ACK;
    [self reloadMessage:msgLocalID];
}

-(void)onPeerMessageFailure:(int)msgLocalID uid:(int64_t)uid{
    IMessage *msg = [self getImMessageById:msgLocalID];
    msg.flags = msg.flags & MESSAGE_FLAG_FAILURE;
    [self reloadMessage:msgLocalID];
}

-(void)onGroupMessage:(IMMessage*)msg{
    
}

-(void)onGroupMessageACK:(int)msgLocalID gid:(int64_t)gid{
    
}

-(void)onGroupMessageFailure:(int)msgLocalID gid:(int64_t)gid{
    
}

//用户连线状态
-(void)onOnlineState:(int64_t)uid state:(BOOL)on{
    if (on) {
        
        [self.navigationBarButtonsView.conectInformationLabel setText:@"对方在线"];
        self.curUser.onlineState = UserOnlineStateOnline;
    }else{
        
        [self.navigationBarButtonsView.conectInformationLabel setText:@"对方不在线"];
        self.curUser.onlineState = UserOnlineStateOffline;
    }
    
}

//对方正在输入
-(void)onPeerInputing:(int64_t)uid{
  
    [self.navigationBarButtonsView.conectInformationLabel setText:@"对方正在输入"];
  
    self.inputStatusTimer = [NSTimer scheduledTimerWithTimeInterval: 10
                                           target:self
                                         selector:@selector(changeStatusBack)
                                         userInfo:nil
                                        repeats:NO];
    
}




-(void)changeStatusBack{
    
    [self.inputStatusTimer invalidate];
    self.inputStatusTimer = nil;
    if (self.curUser.onlineState == UserOnlineStateOnline) {
        [self.navigationBarButtonsView.conectInformationLabel setText:@"对方在线"];
    }else if(self.curUser.onlineState == UserOnlineStateOffline){
        [self.navigationBarButtonsView.conectInformationLabel setText:@"对方不在线"];
    }
 
}


//同IM服务器连接的状态变更通知
-(void)onConnectState:(int)state{
    
    if (state == STATE_CONNECTING) {
        self.inputToolBarView.sendButton.enabled = NO;
    }else if(state == STATE_CONNECTED){
       self.inputToolBarView.sendButton.enabled = YES;
    }else if(state == STATE_CONNECTFAIL){
        self.inputToolBarView.sendButton.enabled = NO;
    }else if(state == STATE_UNCONNECTED){
        self.inputToolBarView.sendButton.enabled = NO;
    }
}
#pragma mark - UItableView cell process

- (void)scrollToBottomAnimated:(BOOL)animated
{
    if([self.messageArray count] == 0){
        return;
    }
    
    int lastSection = [self.messageArray count] - 1;
    NSMutableArray *array = [self.messageArray objectAtIndex: lastSection];
    int lastRow = [array count] - 1;
    
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:lastRow inSection:lastSection] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView{
    [super textViewDidChange:textView];
    
    self.inputToolBarView.sendButton.enabled = ([textView.text trimWhitespace].length > 0) && ([[IMService instance] connectState] == STATE_CONNECTED);
    
    if((time(NULL) -  self.inputTimestamp) > 10){
        
        self.inputTimestamp = time(NULL);
        MessageInputing *inputing = [[MessageInputing alloc ] init];
        inputing.sender = [UserPresent instance].uid;
        inputing.receiver =self.remoteUser.uid;
        
        [[IMService instance] sendInputing: inputing];
 
    }
    
}

-(void)textViewDidBeginEditing:(UITextView *)textView{
    [super textViewDidBeginEditing:textView];
    

    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.timestamps != nil) {
        return [self.timestamps count];
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.messageArray != nil) {
        
        NSMutableArray *array = [self.messageArray objectAtIndex: section];
        return [array count];
    }
    
    return 1;
}

#pragma mark -  UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    if (tableView == self.tableView) {
        if (indexPath.section == 0 &&  indexPath.row == 0) {
            return NO;
        }else{
            return YES;
        }
    }
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    
    MessageTableSectionHeaderView *sectionView = [[[NSBundle mainBundle]loadNibNamed:@"MessageTableSectionHeaderView" owner:self options:nil] lastObject];
    NSDate *curtDate = [self.timestamps objectAtIndex: section];
    NSDate *todayDate = [NSDate date];
    NSString *timeStr = nil;
    if ([PublicFunc isTheDay:curtDate sameToThatDay:todayDate] ) {
        //当天
        int hour = [PublicFunc getHourComponentOfDate:curtDate];
        int minute = [PublicFunc getMinuteComponentOfDate:curtDate];
        int second = [PublicFunc getSecondeComponentOfDate:curtDate];
        timeStr = [NSString stringWithFormat:@"%d:%d:%D",hour,minute,second];
        sectionView.sectionHeader.text = timeStr;
        
    }else{
        int week = [PublicFunc getWeekDayComponentOfDate: curtDate];
        NSString *weekStr = [PublicFunc getWeekDayString: week];
        sectionView.sectionHeader.text = weekStr;
    }
    
    return sectionView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 44;
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{

}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    
    
}


#pragma mark - Messages view delegate

- (BOOL)sendMessage:(IMessage*)msg {
    Message *m = [[Message alloc] init];
    m.cmd = MSG_IM;
    IMMessage *im = [[IMMessage alloc] init];
    im.sender = msg.sender;
    im.receiver = msg.receiver;
    im.msgLocalID = msg.msgLocalID;
    im.content = msg.content.raw;
    m.body = im;
    BOOL r = [[IMService instance] sendPeerMessage:im];
    NSLog(@"send result:%d", r);
    return r;
}

- (void) sendPressed:(UIButton *)sender withText:(NSString *)text {
    
    IMessage *msg = [[IMessage alloc] init];
    
    msg.sender = [UserPresent instance].uid;
    msg.receiver = self.remoteUser.uid;
    
    MessageContent *content = [[MessageContent alloc] init];
    content.raw = text;
    msg.content = content;
    msg.timestamp = time(NULL);

    [[PeerMessageDB instance] insertPeerMessage:msg uid:msg.receiver];
    
    [self addMessageToTheTableView:msg];
    
    [self sendMessage:msg];
    
    [JSMessageSoundEffect playMessageSentSound];
    
    NSNotification* notification = [[NSNotification alloc] initWithName:SEND_FIRST_MESSAGE_OK object: msg userInfo:nil];

    [[NSNotificationCenter defaultCenter] postNotification:notification];
    
    [self finishSend];
    
}

- (void)cameraPressed:(id)sender{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:NULL];
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *array = [self.messageArray objectAtIndex: indexPath.section];
    IMessage * msg =  [array objectAtIndex:indexPath.row];
    if(msg.sender == [UserPresent instance].uid){
        return JSBubbleMessageTypeOutgoing;
    }else{
        return JSBubbleMessageTypeIncoming;
    }
    
}

- (JSBubbleMediaType)messageMediaTypeForRowAtIndexPath:(NSIndexPath *)indexPath{
    return JSBubbleMediaTypeText;
}

- (UIButton *)sendButton
{
    return [UIButton defaultSendButton];
}

- (JSInputBarStyle)inputBarStyle
{
    return JSInputBarStyleFlat;
}

#pragma mark - Messages view data source

- (IMessage*)messageForRowAtIndexPath:(NSIndexPath *)indexPath{

    NSMutableArray *array = [self.messageArray objectAtIndex: indexPath.section];
    IMessage *msg =  ((IMessage*)[array objectAtIndex:indexPath.row]);
    if(msg){
        return msg;
    }
    return nil;
}

- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *array = [self.messageArray objectAtIndex: indexPath.section];
    
    if([array objectAtIndex:indexPath.row]){
        return ((IMessage*)[array objectAtIndex:indexPath.row]).content.raw;
    }
    return nil;
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.timestamps objectAtIndex:indexPath.row];
}

- (UIImage *)avatarImageForIncomingMessage
{
    return [UIImage imageNamed:@"head1.png"];
}

- (UIImage *)avatarImageForOutgoingMessage
{
    return [UIImage imageNamed:@"head2.png"];
}

- (id)dataForRowAtIndexPath:(NSIndexPath *)indexPath{
   return nil;
    
}

#pragma UIImagePicker Delegate

#pragma mark - Image picker delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	NSLog(@"Chose image!  Details:  %@", info);
    
    self.willSendImage = [info objectForKey:UIImagePickerControllerEditedImage];
    [self.timestamps addObject:[NSDate date]];
    [self.tableView reloadData];
    [self scrollToBottomAnimated:YES];
    
	
    [self dismissViewControllerAnimated:YES completion:NULL];
    
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
    
}


- (void)navBarUserheadAction{
    NSLog(@"头像");

    MessageShowThePotraitViewController *controller = [[MessageShowThePotraitViewController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
    
}

- (void) processConversationData{
    
    self.messageArray = [NSMutableArray array];
    self.timestamps = [NSMutableArray array];
    
    NSDate *lastDate = nil;
    NSDate *curtDate = nil;
    NSMutableArray *msgBlockArray = nil;
    id<IMessageIterator> iterator =  [[PeerMessageDB instance] newPeerMessageIterator: self.remoteUser.uid];
    IMessage *msg = [iterator next];
    while (msg) {
        curtDate = [NSDate dateWithTimeIntervalSince1970: msg.timestamp];
        if ([PublicFunc isTheDay:lastDate sameToThatDay:curtDate]) {
            [msgBlockArray insertObject:msg atIndex:0];
        } else {
            msgBlockArray  = [NSMutableArray arrayWithObject:msg];
            
            [self.messageArray insertObject:msgBlockArray atIndex:0];
            [self.timestamps insertObject:curtDate atIndex:0];
            lastDate = curtDate;
        }
        msg = [iterator next];
    }
}

-(NSIndexPath *) insertMsgToMessageBlokArray:(IMessage*)msg{
    NSAssert(msg.msgLocalID, @"");
    
    
    
    NSDate *curtDate = [NSDate dateWithTimeIntervalSince1970: msg.timestamp];
    NSMutableArray *msgBlockArray = nil;
    //收到第一个消息
    if ([self.messageArray count] == 0 ) {
        
        msgBlockArray = [[NSMutableArray alloc] init];
        [self.messageArray addObject: msgBlockArray];
        [msgBlockArray addObject:msg];
        
        [self.timestamps addObject: curtDate];
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        return indexPath;
    }else{
        NSDate *lastDate = [self.timestamps lastObject];
        if ([PublicFunc isTheDay: lastDate sameToThatDay: curtDate]) {
            //same day
            msgBlockArray = [self.messageArray lastObject];
            [msgBlockArray addObject:msg];
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[msgBlockArray count] - 1 inSection: [self.messageArray count] - 1];
            return indexPath;
        }else{
            //next day
            msgBlockArray = [[NSMutableArray alloc] init];
            [msgBlockArray addObject: msg];
            [self.messageArray addObject: msgBlockArray];
            [self.timestamps addObject:curtDate];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[msgBlockArray count] - 1 inSection: [self.messageArray count] - 1];
            return indexPath;
        }
    }
}

#pragma mark - function

-(void) setNormalNavigationButtons{
    
    UIButton *imgButton = [[UIButton alloc] initWithFrame: CGRectMake(0,0,navBarHeadButtonSize,navBarHeadButtonSize)];
    
    [imgButton setImage: [UIImage  imageNamed:@"head1.png"] forState: UIControlStateNormal];
    [imgButton addTarget:self action:@selector(navBarUserheadAction) forControlEvents:UIControlEventTouchUpInside];
    
    CALayer *imageLayer = [imgButton layer];   //获取ImageView的层
    [imageLayer setMasksToBounds:YES];
    [imageLayer setCornerRadius:imgButton.frame.size.width/2];
    
    UIBarButtonItem *navBarHeadButton = [[UIBarButtonItem alloc] initWithCustomView: imgButton];
    self.navigationItem.rightBarButtonItem = navBarHeadButton;
    
 
    
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"对话"
                                                             style:UIBarButtonItemStyleDone
                                                            target:self
                                                            action:@selector(returnMainTableViewController)];

    self.navigationItem.leftBarButtonItem = item;
}

- (IMessage*) getImMessageById:(int)msgLocalID{
    
    for ( int sectionIndex = [self.messageArray count] - 1; sectionIndex >= 0; sectionIndex--) {
        
        NSMutableArray *rowArrays = [self.messageArray objectAtIndex:sectionIndex];
        for (int rowindex = [rowArrays count ] - 1;rowindex >= 0 ; rowindex--) {
            
            IMessage *tmpMsg = (IMessage*) [rowArrays objectAtIndex:rowindex];
            if (tmpMsg.msgLocalID == msgLocalID) {
                return tmpMsg;
            }
        }
    }
    return nil;
}


- (void) reloadMessage:(int)msgLocalID{
    
    for ( int sectionIndex = [self.messageArray count] - 1; sectionIndex >= 0; sectionIndex--) {
        
        NSMutableArray *rowArrays = [self.messageArray objectAtIndex:sectionIndex];
        for (int rowindex = [rowArrays count ] - 1;rowindex >= 0 ; rowindex--) {
            
            IMMessage *tmpMsg = [rowArrays objectAtIndex:rowindex];
            if (tmpMsg.msgLocalID == msgLocalID) {
                
                NSIndexPath *findpath = [NSIndexPath indexPathForRow:rowindex inSection: sectionIndex];
                NSArray *array = [NSArray arrayWithObject:findpath];
                [self.tableView reloadRowsAtIndexPaths:array withRowAnimation:UITableViewRowAnimationMiddle];
            }
        }
    }
}

-(void) addMessageToTheTableView:(IMessage*) msg{
    
    NSIndexPath *indexPath = [self insertMsgToMessageBlokArray: msg];
    
    if (indexPath.row == 0 ) {
        
        NSUInteger sectionCount = indexPath.section;
        NSIndexSet *indices = [NSIndexSet indexSetWithIndex: sectionCount];
        [self.tableView beginUpdates];
        [self.tableView insertSections:indices withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView endUpdates];
        
    }else{
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        [indexPaths addObject: indexPath];
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }
    
}

-(void)returnMainTableViewController {
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    delegate.tabBarController.selectedIndex = 2;
    [self.navigationController popToRootViewControllerAnimated:YES];
}
@end

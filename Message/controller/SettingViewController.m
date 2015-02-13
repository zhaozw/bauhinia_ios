//
//  SettingViewController.m
//  Message
//
//  Created by daozhu on 14-6-16.
//  Copyright (c) 2014年 daozhu. All rights reserved.
//

#import "SettingViewController.h"
#import "AboutViewController.h"
#import "ProfileViewController.h"

#import "ConversationSettingViewController.h"
#import "PeerMessageDB.h"
#import "UIView+Toast.h"
#import "APIRequest.h"


#define kNetStatusSection 2
#define kNetStatusRow     0
#define kClearAllConversationSection 3

#define kClearAllContentTag  101

#define kAboutCellTag                   100

#define kProfileCellTag                 200
#define kConversationCellSettingTag     201
#define kZbarScanCellTag                202

#define kNetStatusCellTag               300

#define kClearConversationCellTag       400

#define kGreenColor         RGBCOLOR(48,176,87)
#define kRedColor           RGBCOLOR(207,6,6)

@interface SettingViewController ()

@end

@implementation SettingViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.cellTitleArray = @[ @"关于",
                                 @[@"个人资讯",@"会话设置",@"Web端登录"],
                                 @"网络状态",
                                 @"清除所有对话记录"
                                ];
        [[IMService instance] addMessageObserver:self];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
}

- (void)viewDidAppear:(BOOL)animated{

}

-(void)viewDidDisappear:(BOOL)animated{

}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{

    return [self.cellTitleArray count];

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
   
    id array = [self.cellTitleArray objectAtIndex:section];
    if ([array isKindOfClass:[NSString class]]) {
        return 1;
    }else if([array isKindOfClass:[NSArray class]]){
        return [(NSArray*)array count];
    }
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
   
    UITableViewCell *cell = nil;
    NSLog(@"%d,%d",indexPath.section,indexPath.row);
    if (indexPath.section != kClearAllConversationSection) {
        if(indexPath.section == kNetStatusSection && indexPath.row == kNetStatusRow){
            cell  = [tableView dequeueReusableCellWithIdentifier:@"statuscell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"statuscell"];
            }
            [cell.detailTextLabel setFont:[UIFont systemFontOfSize:16.0f]];
            cell.tag = (indexPath.section + 1) * 100 + indexPath.row;
            if ([[IMService instance] connectState] != STATE_CONNECTED) {
                [self addActivityView:cell];
            }else{
                [cell.detailTextLabel setTextColor: kGreenColor];
                [cell.detailTextLabel setText:@"已链接"];
            }
            
        }else{
            cell  = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"simplecell"];
            }
            cell.tag = (indexPath.section + 1 ) * 100 + indexPath.row;
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
        
    }else if(indexPath.section == kClearAllConversationSection){
        cell = [tableView dequeueReusableCellWithIdentifier:@"clearCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"clearcell"];
            cell.tag = (indexPath.section + 1) * 100 + indexPath.row;
            [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
            [cell.textLabel setTextColor:kRedColor];
        }
    }
    
    id array = [self.cellTitleArray objectAtIndex:indexPath.section];
    if ([array isKindOfClass:[NSString class]]) {
        [cell.textLabel setText: array];
    }else if([array isKindOfClass:[NSArray class]]){
        [cell.textLabel setText: [array objectAtIndex:indexPath.row]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
     [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    int cellTag = (indexPath.section + 1) *100 + indexPath.row;
    switch (cellTag) {
        case kAboutCellTag:
        {
           AboutViewController * aboutController = [[AboutViewController alloc] init];
            
            aboutController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:aboutController animated: YES];
        }
            break;
        case kProfileCellTag:
        {
            ProfileViewController * profileController = [[ProfileViewController alloc] init];
            profileController.editorState = ProfileEditorSettingType;
            profileController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:profileController animated: YES];
        }
            break;
        case kConversationCellSettingTag:
        {
            
            ConversationSettingViewController * conSettingController = [[ConversationSettingViewController alloc] init];
            
            conSettingController.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:conSettingController animated: YES];
        }
            break;
        case kZbarScanCellTag:
        {
            [self scan:nil];
        }
            break;
        case kNetStatusCellTag:
        {

        }
            break;
        case kClearConversationCellTag:
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"确认" message:@"是否清除所有聊天记录?" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确认", nil];
            alertView.tag = kClearAllContentTag;
            [alertView show];
        }
            break;
        default:
            break;
    }
   
    
}

#pragma mark - MessageObserver
-(void) onConnectState:(int)state {
   NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kNetStatusRow inSection:kNetStatusSection];
    UITableViewCell *cell  = [self.tableView cellForRowAtIndexPath:indexPath];
    switch (state) {
        case STATE_UNCONNECTED:
        {
            [cell.detailTextLabel setTextColor:kGreenColor];
            [cell.detailTextLabel setText:@"未链接.."];
            [self hideActivityView:cell];
        }
            break;
        case STATE_CONNECTING :
        {
            [cell.detailTextLabel setTextColor:kGreenColor];
            [cell.detailTextLabel setText:@""];
            [self addActivityView:cell];
        }
            break;
        case STATE_CONNECTED :
        {
            [cell.detailTextLabel setTextColor:kGreenColor];
            [cell.detailTextLabel setText:@"已链接"];
            [self hideActivityView:cell];
        }
            break;
        case STATE_CONNECTFAIL :
        {
            [cell.detailTextLabel setTextColor:kRedColor];
            [cell.detailTextLabel setText:@"未链接"];
            [self hideActivityView:cell];
        }
            break;
        default:
            break;
    }

}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (alertView.tag == kClearAllContentTag) {
        if (buttonIndex == 0) {
        //取消
            
        }else if(buttonIndex == 1){
        //确认
          BOOL result =  [[PeerMessageDB instance] clear];
            if (result) {
                
                NSNotification* notification = [[NSNotification alloc] initWithName:CLEAR_ALL_CONVESATION object: nil userInfo:nil];
                [[NSNotificationCenter defaultCenter] postNotification:notification];
                
                [self.view makeToast:@"会话清理完毕" duration:0.9 position:@"center"];
            }
        }
    }
}



#pragma mark - UITableViewDelegate

-(void) addActivityView:(UITableViewCell*)cell{
    if (cell.accessoryView&& [cell.accessoryView isKindOfClass:[UIActivityIndicatorView class]]){
        [cell.accessoryView setHidden:NO];
        [(UIActivityIndicatorView*)cell.accessoryView startAnimating]; // 开始旋转
    }else{
        UIActivityIndicatorView *testActivityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        cell.accessoryView = testActivityIndicator;
        testActivityIndicator.color = [UIColor grayColor];
        [testActivityIndicator startAnimating]; // 开始旋转
        [testActivityIndicator setHidesWhenStopped:YES];
    }
}

-(void)hideActivityView:(UITableViewCell*)cell{
    if(cell.accessoryView&&[cell.accessoryView isKindOfClass:[UIActivityIndicatorView class]]){
        [(UIActivityIndicatorView*)cell.accessoryView stopAnimating];
        cell.accessoryView = nil;
    }
}


- (void)scan:(id)sender {
    
    ZBarReaderController * reader = [ZBarReaderController new];
    reader.readerDelegate = self;
    ZBarImageScanner * scanner = reader.scanner;
    [scanner setSymbology:ZBAR_I25 config:ZBAR_CFG_ENABLE to:0];
    
    reader.showsZBarControls = YES;
    
    [self presentViewController:reader animated:YES completion:nil];
}

#pragma mark - ZBarReaderDelegate

- (void) readerControllerDidFailToRead: (ZBarReaderController*) reader
                             withRetry: (BOOL) retry{
    
}


-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    id<NSFastEnumeration> results = [info objectForKey:ZBarReaderControllerResults];
    ZBarSymbol * symbol;
    for(symbol in results)
        break;
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSString *text = symbol.data;
    
    [APIRequest webIMlogin:text
                        success:^{
                            NSLog(@"web login success");
                            [self.view makeToast:@"WebIM登录成功!" duration:0.9 position:@"center"];
                        }
                           fail:^{
                               NSLog(@"web login fail");
                               [self.view makeToast:@"WebIM登录失败!" duration:0.9 position:@"center"];
                           }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

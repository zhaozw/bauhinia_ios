//
//  IMService.m
//  im
//
//  Created by houxh on 14-6-26.
//  Copyright (c) 2014年 potato. All rights reserved.
//

#import "IMService.h"
#import "AsyncTCP.h"
#import "Message.h"
#import "IMessage.h"
#import "MessageDB.h"
#import "util.h"

#define HEARTBEAT (10ull*NSEC_PER_SEC)



@interface IMService()
@property(nonatomic, assign)BOOL stopped;
@property(nonatomic)AsyncTCP *tcp;
@property(nonatomic, strong)dispatch_source_t connectTimer;
@property(nonatomic, strong)dispatch_source_t heartbeatTimer;
@property(nonatomic)int connectFailCount;
@property(nonatomic)int seq;
@property(nonatomic)NSMutableArray *observers;
@property(nonatomic)NSMutableData *data;
@property(nonatomic)int64_t uid;
@property(nonatomic)NSMutableDictionary *peerMessages;
@property(nonatomic)NSMutableDictionary *groupMessages;
@end

@implementation IMService
+(IMService*)instance {
    static IMService *im;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!im) {
            im = [[IMService alloc] init];
        }
    });
    return im;
}

-(id)init {
    self = [super init];
    if (self) {
        dispatch_queue_t queue = dispatch_get_main_queue();
        self.connectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
        dispatch_source_set_event_handler(self.connectTimer, ^{
            [self connect];
        });

        self.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
        dispatch_source_set_event_handler(self.heartbeatTimer, ^{
            [self sendHeartbeat];
        });
        self.observers = [NSMutableArray array];
        self.data = [NSMutableData data];
        self.peerMessages = [NSMutableDictionary dictionary];
        self.groupMessages = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)start:(int64_t)uid {
    if (!self.host || !self.port) {
        NSLog(@"should init im server host and port");
        exit(1);
    }
    NSLog(@"start im service");
    self.uid = uid;
    self.stopped = NO;
    dispatch_time_t w = dispatch_walltime(NULL, 0);
    dispatch_source_set_timer(self.connectTimer, w, DISPATCH_TIME_FOREVER, 0);
    dispatch_resume(self.connectTimer);
    
    w = dispatch_walltime(NULL, HEARTBEAT);
    dispatch_source_set_timer(self.heartbeatTimer, w, HEARTBEAT, HEARTBEAT/2);
    dispatch_resume(self.heartbeatTimer);
}

-(void)stop {
    self.stopped = YES;
    dispatch_suspend(self.connectTimer);
    dispatch_suspend(self.heartbeatTimer);
    [self close];
}

-(void)close {
    if (self.tcp) {
        __weak IMService *wself = self;
        [self.tcp close:^(AsyncTCP *tcp, int err) {
            [wself onClose];
        }];
    }
}

-(void)onClose {
    NSLog(@"im service on close");
    self.tcp = nil;
    if (self.stopped) return;
    
    NSLog(@"start connect timer");
    //重连
    int64_t t = 0;
    if (self.connectFailCount > 60) {
        t = 60ull*NSEC_PER_SEC;
    } else {
        t = self.connectFailCount*NSEC_PER_SEC;
    }
    
    t = 10ull*NSEC_PER_SEC;
    dispatch_time_t w = dispatch_walltime(NULL, t);
    dispatch_source_set_timer(self.connectTimer, w, DISPATCH_TIME_FOREVER, 0);

}

-(void)handleACK:(Message*)msg {
    NSNumber *seq = (NSNumber*)msg.body;
    IMessage *m = (IMessage*)[self.peerMessages objectForKey:seq];
    IMessage *m2 = (IMessage*)[self.groupMessages objectForKey:seq];
    if (!m && !m2) {
        return;
    }
    if (m) {
        [[MessageDB instance] acknowledgePeerMessage:m.msgLocalID uid:m.receiver];
        [self.peerMessages removeObjectForKey:seq];
        [self publishPeerMessageACK:m.msgLocalID uid:m.receiver];
    } else if (m2) {
        [[MessageDB instance] acknowledgeGroupMessage:m2.msgLocalID gid:m2.receiver];
        [self.groupMessages removeObjectForKey:seq];
        [self publishGroupMessageACK:m2.msgLocalID gid:m2.receiver];
    }
}

-(void)handleIMMessage:(Message*)msg {
    IMMessage *im = (IMMessage*)msg.body;
    IMessage *m = [[IMessage alloc] init];
    m.sender = im.sender;
    m.receiver = im.receiver;
    MessageContent *content = [[MessageContent alloc] init];
    content.raw = im.content;
    m.content = content;
    m.timestamp = time(NULL);
    [[MessageDB instance] insertPeerMessage:m uid:im.sender];
    
    NSLog(@"sender:%lld receiver:%lld content:%s", im.sender, im.receiver, [im.content UTF8String]);
    Message *ack = [[Message alloc] init];
    ack.cmd = MSG_ACK;
    ack.body = [NSNumber numberWithInt:msg.seq];
    [self sendMessage:ack];
    [self publishPeerMessage:m];
}

-(void)handleGroupIMMessage:(Message*)msg {
    IMMessage *im = (IMMessage*)msg.body;
    IMessage *m = [[IMessage alloc] init];
    m.sender = im.sender;
    m.receiver = im.receiver;
    MessageContent *content = [[MessageContent alloc] init];
    content.raw = im.content;
    m.content = content;
    m.timestamp = time(NULL);
    [[MessageDB instance] insertGroupMessage:m];
    
    NSLog(@"sender:%lld receiver:%lld content:%s", im.sender, im.receiver, [im.content UTF8String]);
    Message *ack = [[Message alloc] init];
    ack.cmd = MSG_ACK;
    ack.body = [NSNumber numberWithInt:msg.seq];
    [self sendMessage:ack];
    [self publishGroupMessage:m];
}

-(void)handleAuthStatus:(Message*)msg {
    int status = [(NSNumber*)msg.body intValue];
    NSLog(@"auth status:%d", status);
}

-(void)handleInputing:(Message*)msg {
    MessageInputing *inputing = (MessageInputing*)msg.body;
    for (id<MessageObserver> ob in self.observers) {
        [ob onPeerInputing:inputing.sender];
    }
}

-(void)handlePeerACK:(Message*)msg {
    MessagePeerACK *ack = (MessagePeerACK*)msg.body;
    for (id<MessageObserver> ob in self.observers) {
        [ob onPeerMessageACK:ack.msgLocalID uid:ack.sender];
    }
}

-(void)handleOnlineState:(Message*)msg {
    MessageOnlineState *state = (MessageOnlineState*)msg.body;
    for (id<MessageObserver> ob in self.observers) {
        [ob onOnlineState:state.sender state:state.online];
    }
}

-(void)publishPeerMessage:(IMessage*)msg {
    for (id<MessageObserver> ob in self.observers) {
        [ob onPeerMessage:msg];
    }
}

-(void)publishPeerMessageACK:(int)msgLocalID uid:(int64_t)uid {
    for (id<MessageObserver> ob in self.observers) {
        [ob onPeerMessageACK:msgLocalID uid:uid];
    }
}

-(void)publishGroupMessage:(IMessage*)msg {
    for (id<MessageObserver> ob in self.observers) {
        [ob onGroupMessage:msg];
    }
}

-(void)publishGroupMessageACK:(int)msgLocalID gid:(int64_t)gid {
    for (id<MessageObserver> ob in self.observers) {
        [ob onGroupMessageACK:msgLocalID gid:gid];
    }
}

-(void)publishConnectState:(int)state {
    for (id<MessageObserver> ob in self.observers) {
        [ob onConnectState:state];
    }
}

-(void)handleMessage:(Message*)msg {
    if (msg.cmd == MSG_AUTH_STATUS) {
        [self handleAuthStatus:msg];
    } else if (msg.cmd == MSG_ACK) {
        [self handleACK:msg];
    } else if (msg.cmd == MSG_IM) {
        [self handleIMMessage:msg];
    } else if (msg.cmd == MSG_GROUP_IM) {
        [self handleGroupIMMessage:msg];
    } else if (msg.cmd == MSG_INPUTING) {
        [self handleInputing:msg];
    } else if (msg.cmd == MSG_PEER_ACK) {
        [self handlePeerACK:msg];
    } else if (msg.cmd == MSG_ONLINE_STATE) {
        [self handleOnlineState:msg];
    }
}

-(BOOL)handleData:(NSData*)data {
    [self.data appendData:data];
    int pos = 0;
    const uint8_t *p = [self.data bytes];
    while (YES) {
        if (self.data.length < pos + 4) {
            break;
        }
        int len = readInt32(p+pos);
        if (self.data.length < 4 + 8 + pos + len) {
            break;
        }
        NSData *tmp = [NSData dataWithBytes:p+4+pos length:len + 8];
        Message *msg = [[Message alloc] init];
        if (![msg unpack:tmp]) {
            NSLog(@"unpack message fail");
            return NO;
        }
        [self handleMessage:msg];
        pos += 4+8+len;
    }
    self.data = [NSMutableData dataWithBytes:p+pos length:self.data.length - pos];
    return YES;
}

-(void)onRead:(NSData*)data error:(int)err {
    if (err) {
        NSLog(@"tcp read err");
        [self close];
        return;
    } else if (!data) {
        NSLog(@"tcp closed");
        [self close];
        return;
    } else {
        BOOL r = [self handleData:data];
        if (!r) {
            [self close];
        }
    }
}

-(void)connect {
    if (self.tcp) {
        return;
    }
    if (self.stopped) {
        NSLog(@"opps......");
        return;
    }
    
    [self publishConnectState:STATE_CONNECTING];
    
    self.tcp = [[AsyncTCP alloc] init];
    __weak IMService *wself = self;
    [self.tcp connect:@"127.0.0.1" port:23000 cb:^(AsyncTCP *tcp, int err) {
        if (err) {
            NSLog(@"tcp connect err");
            wself.connectFailCount = wself.connectFailCount + 1;
            [wself close];
            [self publishConnectState:STATE_CONNECTFAIL];
            return;
        } else {
            NSLog(@"tcp connected");
            wself.connectFailCount = 0;
            [self publishConnectState:STATE_CONNECTED];
            [self sendAuth];
            [wself.tcp startRead:^(AsyncTCP *tcp, NSData *data, int err) {
                [wself onRead:data error:err];
            }];
        }
    }];
}

-(void)addMessageObserver:(id<MessageObserver>)ob {
    [self.observers addObject:ob];
}
-(void)removeMessageObserver:(id<MessageObserver>)ob {
    [self.observers removeObject:ob];
}

-(BOOL)sendPeerMessage:(IMessage *)msg {
    Message *m = [[Message alloc] init];
    m.cmd = MSG_IM;
    IMMessage *im = [[IMMessage alloc] init];
    im.sender = msg.sender;
    im.receiver = msg.receiver;
    im.content = msg.content.raw;
    m.body = im;
    BOOL r = [self sendMessage:m];

    if (!r) return r;
    [self.peerMessages setObject:msg forKey:[NSNumber numberWithInt:m.seq]];
    return r;
}

-(BOOL)sendGroupMessage:(IMessage *)msg {
    Message *m = [[Message alloc] init];
    m.cmd = MSG_GROUP_IM;
    IMMessage *im = [[IMMessage alloc] init];
    im.sender = msg.sender;
    im.receiver = msg.receiver;
    im.content = msg.content.raw;
    m.body = im;
    BOOL r = [self sendMessage:m];
    
    if (!r) return r;
    [self.groupMessages setObject:msg forKey:[NSNumber numberWithInt:m.seq]];
    return r;
}

-(BOOL)sendMessage:(Message *)msg {
    if (!self.tcp) return NO;
    self.seq = self.seq + 1;
    msg.seq = self.seq;

    NSMutableData *data = [NSMutableData data];
    NSData *p = [msg pack];
    if (!p) {
        NSLog(@"message pack error");
        return NO;
    }
    char b[4];
    writeInt32(p.length-8, b);
    [data appendBytes:(void*)b length:4];
    [data appendData:p];
    [self.tcp write:data];
    return YES;
}

-(void)sendHeartbeat {
    NSLog(@"send heartbeat");
    Message *msg = [[Message alloc] init];
    msg.cmd = MSG_HEARTBEAT;
    [self sendMessage:msg];
}

-(void)sendAuth {
    NSLog(@"send auth");
    Message *msg = [[Message alloc] init];
    msg.cmd = MSG_AUTH;
    msg.body = [NSNumber numberWithLongLong:self.uid];
    [self sendMessage:msg];
}

//正在输入
-(void)sendInputing:(MessageInputing*)inputing {
    Message *msg = [[Message alloc] init];
    msg.cmd = MSG_INPUTING;
    msg.body = inputing;
    [self sendMessage:msg];
}

//订阅用户在线状态通知消息
-(void)subscribeState:(MessageSubsribe*)sub {
    Message *msg = [[Message alloc] init];
    msg.cmd = MSG_SUBSCRIBE_ONLINE_STATE;
    msg.body = sub;
    [self sendMessage:msg];
}
@end
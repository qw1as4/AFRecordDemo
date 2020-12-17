//
//  AFRecordingViewController.m
//  LZZS
//
//  Created by 阿福 on 2020/12/14.
//  Copyright © 2020  chuanqi.wang. All rights reserved.
//

#import "AFRecordingViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "lame.h"
// 设置控制中心交互需要导入
#import <MediaPlayer/MediaPlayer.h>

#define SCREEN_HEIGHT [[UIScreen mainScreen] bounds].size.height
#define SCREEN_WIDTH [[UIScreen mainScreen] bounds].size.width
#define KFILESIZE (1 * 1024 * 1024)

static const NSInteger AVSampleRate = 8000;

@interface AFRecordingViewController ()<AVAudioRecorderDelegate,UITableViewDelegate,UITableViewDataSource>
{
    NSTimer *_timer; //定时器
    NSInteger countDown;  //倒计时
    UIButton * recordBtn;
    UILabel * noticeLabel;
    UILabel * textLab;
    NSString *filePath;  //文件地址
    NSURL *recordFileUrl; //文件地址
}
@property(nonatomic, strong)AVAudioRecorder * audioRecorder;//录音器
@property(nonatomic, strong)AVPlayer *player; //播放器
@property(nonatomic, strong)UITableView *tableView;
@property(nonatomic, strong)NSMutableArray *dataArr;
@property(nonatomic, strong)UIView *playView; //播放页面
@property(nonatomic, strong)UISlider *playSlider;
//当前歌曲进度监听者
@property(nonatomic,strong) id timeObserver;

@end

@implementation AFRecordingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createView];
}

-(void)createView
{
    self.view.backgroundColor = [UIColor whiteColor];
    recordBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
    recordBtn.frame = CGRectMake(SCREEN_WIDTH/2-50, 60, 100, 30);
    [recordBtn setTitle:@"开始录音" forState:(UIControlStateNormal)];
    [recordBtn setTitle:@"停止录音" forState:(UIControlStateSelected)];
    [recordBtn addTarget:self action:@selector(startRecordAction:) forControlEvents:(UIControlEventTouchUpInside)];
    recordBtn.backgroundColor = [UIColor blueColor];
    [self.view addSubview:recordBtn];
    
    noticeLabel = [[UILabel alloc] init];
    noticeLabel.text = @"文件大小";
    noticeLabel.frame = CGRectMake(0, 100, SCREEN_WIDTH, 30);
    noticeLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:noticeLabel];
    
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.playView];

    NSString * string = [self recordCacheDirectory];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSArray * tempArr = [NSArray arrayWithArray:[fileManager contentsOfDirectoryAtPath:string error:nil]];
    self.dataArr = [NSMutableArray arrayWithArray:tempArr];
    [self.tableView reloadData];
}

// 设置session判断权限
- (void)prepareRecord:(void(^)(BOOL granted))completeHandler {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    // 监听来电等事件打断音乐播放，此广播是系统发出的，监听即可
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:session];
    // 监听音频输出变化事件，插拔耳机、连接蓝牙等事件，此广播是系统发出的，监听即可
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:session];

    NSError *error;
    NSLog(@"Error creating session: %@", [error description]);
    //设置为录音和语音播放模式，支持边录音边使用扬声器，与其他应用同时使用麦克风和扬声器
    //[session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions: AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:&error];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    NSLog(@"Error creating session: %@", [error description]);
    //启动音频会话管理,此时会阻断后台音乐的播放
    [session setActive:YES error:nil];
    //判断是否授权录音
    [session requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completeHandler(granted);
        });
    }];
}

// 录音设置
- (NSDictionary *)audioSetting {
    static NSMutableDictionary *setting = nil;
    
    if (setting == nil) {
        setting = [NSMutableDictionary dictionary];
        //音频格式
        setting[AVFormatIDKey] = @(kAudioFormatMPEG4AAC);
        //采样率  8000/11025/22050/44100/96000（影响音频的质量）
        setting[AVSampleRateKey] = @(AVSampleRate);
        //音频通道数1或2 由于需要压缩为MP3格式，所以此处必须为双声道
        setting[AVNumberOfChannelsKey] = @(1);
        //采样位数  8、16、24、32 默认为16
        setting[AVLinearPCMBitDepthKey] = @(8);
        //录音质量
        setting[AVEncoderAudioQualityKey] = @(AVAudioQualityMin);
    }
    return setting;
}

// 录音按钮点击事件
-(void)startRecordAction:(UIButton *)sender
{
    if (sender.isSelected == NO) {
        [self startPrepareRecord];
        sender.selected = YES;
    } else {
        [self stopRecord];
        sender.selected = NO;
    }
}

//准备开始录音
- (void)startPrepareRecord {
    [self prepareRecord:^(BOOL granted) {
        if (granted) {
            [self startRecord];
        }else {
            //进行鉴权申请等操作
        }
    }];
}

//开始录音
- (void)startRecord {
    [self addTimer];
    NSDictionary *setting = [self audioSetting];
    filePath = [self recordFilePath];
    recordFileUrl = [NSURL URLWithString:filePath];
    NSError *error = nil;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:recordFileUrl settings:setting error:&error];
    if (error) {
        NSLog(@"创建录音机时发生错误，信息：%@",error.localizedDescription);
    }else {
        self.audioRecorder.delegate = self;
        self.audioRecorder.meteringEnabled = YES;
        [self.audioRecorder prepareToRecord];
        [self.audioRecorder record];
        NSLog(@"录音开始");
    }
}

//停止录音
-(void)stopRecord
{
    [self removeTimer];
    if ([self.audioRecorder isRecording]) {
        [self.audioRecorder stop];
        [[AVAudioSession sharedInstance] setActive:NO error:nil]; //一定要在录音停止以后再关闭音频会话管理
    }
    // 如果是caf可以转mp3
//    [self conventToMp3];
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]){
        NSLog(@"%@",[NSString stringWithFormat:@"文件大小为 %.2fKb",[[manager attributesOfItemAtPath:filePath error:nil] fileSize]/1024.0]);
        noticeLabel.text = [NSString stringWithFormat:@"录了 %ld 秒,文件大小为 %.2fKb",  (long)countDown,[[manager attributesOfItemAtPath:filePath error:nil] fileSize]/1024.0];
    }
    [self.dataArr addObject:[filePath componentsSeparatedByString:@"/"].lastObject];
    [self.tableView reloadData];
}

//开始播放
- (void)playRecord
{
    NSLog(@"播放录音");
    [self.audioRecorder stop];
    
    NSString * path = [[self recordCacheDirectory] stringByAppendingPathComponent:textLab.text];
    NSURL * url = [NSURL fileURLWithPath:path];
    AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
    //替换当前音乐资源
    [self.player replaceCurrentItemWithPlayerItem:item];
    
    self.playSlider.value = 0;
    AVAudioSession *session =[AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [self.player play];
    
    //监听音乐播放的进度
    [self addMusicProgressWithItem:item];
    [self setLockingInfo];
}

//监听音乐播放的进度
-(void)addMusicProgressWithItem:(AVPlayerItem *)item
{
    //移除监听音乐播放进度
    [self removeTimeObserver];
    __weak typeof(self) weakSelf = self;
    self.timeObserver =  [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        //当前播放的时间
        float current = CMTimeGetSeconds(time);
        //总时间
        float total = CMTimeGetSeconds(item.duration);
        if (current) {
            float progress = current / total;
            //更新播放进度条
           weakSelf.playSlider.value = progress;
        }
    }];
    
}

//移除监听音乐播放进度
-(void)removeTimeObserver
{
    if (self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}

// 进度条变化
-(void)progressAction:(UISlider *)slider{
    //根据值计算时间
    float time = slider.value * CMTimeGetSeconds(self.player.currentItem.duration);
    //跳转到当前指定时间
    [self.player seekToTime:CMTimeMake(time, 1)];
}

#pragma mark - UITableViewDelegate,UITableViewDataSource
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArr.count;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"DealerStaffListCellTableViewCellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }
    cell.textLabel.text = [self.dataArr objectAtIndex:indexPath.row];

    // 路径
    NSString * path = [[self recordCacheDirectory] stringByAppendingPathComponent:cell.textLabel.text];
    // 音频时长
    AVURLAsset* audioAsset =[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath: path] options:nil];
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"时长:%.2fs  \n大小:%.2fKb",audioDurationSeconds, [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize]/1024.0];
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    textLab.text = [self.dataArr objectAtIndex:indexPath.row];
    [self playRecord];
}


// 设置锁屏播放界面
- (void)setLockingInfo {

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    //设置歌曲题目
    [dict setObject:@"题目" forKey:MPMediaItemPropertyTitle];
    //设置歌手名
    [dict setObject:@"歌手" forKey:MPMediaItemPropertyArtist];
    //设置专辑名
    [dict setObject:@"专辑" forKey:MPMediaItemPropertyAlbumTitle];

    //设置显示的图片
    //UIImage *newImage = [UIImage imageNamed:@"43.png"];
    //[dict setObject:[[MPMediaItemArtwork alloc] initWithImage:newImage] forKey:MPMediaItemPropertyArtwork];

    //设置歌曲时长
    [dict setObject:[NSNumber numberWithDouble:15.36] forKey:MPMediaItemPropertyPlaybackDuration];
    //设置已经播放时长
    [dict setObject:[NSNumber numberWithDouble:0] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    //更新字典
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
    // 开启远程交互
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

//监听远程交互方法
- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    
    switch (event.subtype) {
        //播放
        case UIEventSubtypeRemoteControlPlay:{
            [self.player play];
                    }
            break;
        //停止
        case UIEventSubtypeRemoteControlPause:{
            [self.player pause];
                   }
            break;
        //下一首
        case UIEventSubtypeRemoteControlNextTrack:
            
            break;
        //上一首
        case UIEventSubtypeRemoteControlPreviousTrack:
            
            break;
            
        default:
            break;
    }
}


//录音被打断
- (void)audioSessionInterruptionNotification:(NSNotification *)notifi {
    
    NSInteger type = [notifi.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
    switch (type) {
        case AVAudioSessionInterruptionTypeBegan: { //打断时暂停录音
                //do something
            NSLog(@"被打断");
            [self stopRecord];
            recordBtn.selected = YES;
        }break;
        case AVAudioSessionInterruptionTypeEnded: {//打断结束
            NSInteger option = [notifi.userInfo[AVAudioSessionInterruptionOptionKey] integerValue];
            if (option == AVAudioSessionInterruptionOptionShouldResume) {
                // 恢复播放
                //do something
            }else {
                //do something
            }
        }break;
    };
    NSLog(@"%@", notifi);
}


// caf转mp3
- (void)conventToMp3 {
    
    //tmpUrl是caf文件的路径，并转换成字符串
    NSString *cafFilePath = [recordFileUrl absoluteString];
    //存储mp3文件的路径
    NSString *mp3FilePath = [NSString stringWithFormat:@"%@.mp3",[NSString stringWithFormat:@"%@",[cafFilePath substringToIndex:cafFilePath.length - 4]]];
    @try {
        int read, write;

        FILE *pcm = fopen([cafFilePath cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
        FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置

        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];

        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 11025.0);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);

        do {
            read = fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);

            fwrite(mp3_buffer, write, 1, mp3);

        } while (read != 0);

        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
        NSLog(@"转换成功");
        BOOL isDelete = [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        if (isDelete) NSLog(@"删除caf文件");
        filePath = mp3FilePath;
        recordFileUrl = [NSURL URLWithString:filePath];
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);

    }
    @finally {

    }
}


// 添加定时器
- (void)addTimer
{
    countDown = 0;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshLabelText) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

// 移除定时器
- (void)removeTimer
{
    [_timer invalidate];
    _timer = nil;
    
}

-(void)refreshLabelText {
    countDown ++;
    noticeLabel.text = [NSString stringWithFormat:@"时长 %ld 秒",(long)countDown];
}

//录音文件的缓存路径
- (NSString *)recordFilePath {
    NSString * path = [[self recordCacheDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.aac",[self getCurrentTimes]]];
    return path;
}

// 获取缓存文件的根目录
- (NSString *)recordCacheDirectory {
    static NSString *directory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *cacheDir = [docDir stringByAppendingPathComponent:@"LZRecord"];
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir = NO;
        BOOL existed = [fm fileExistsAtPath:cacheDir isDirectory:&isDir];
        if (!(isDir && existed)) {
            [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        directory = cacheDir;
    });
    return directory;
}

// 获取当前时间 为音频命名
-(NSString*)getCurrentTimes {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd-HH:mm:ss"];
    NSDate *datenow = [NSDate date];
    NSString *currentTimeString = [formatter stringFromDate:datenow];
    return currentTimeString;
}

#pragma mark - getter
-(AVPlayer *)player
{
    if (_player == nil) {
        //初始化_player
        AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:@""]];
        _player = [[AVPlayer alloc] initWithPlayerItem:item];
    }
    
    return _player;
}

-(UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 140 ,SCREEN_WIDTH, SCREEN_HEIGHT-140-100) style:(UITableViewStylePlain)];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.rowHeight = 50;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return _tableView;
}
    
-(UIView *)playView
{
    if (!_playView) {
        _playView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT-100, SCREEN_WIDTH, 100)];
        _playView.backgroundColor = [UIColor yellowColor];
        
        UIButton * playBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
        playBtn.frame = CGRectMake(10, 10, 80, 80);
        [playBtn setTitle:@"开始播放" forState:(UIControlStateNormal)];
        [playBtn setTitle:@"停止播放" forState:(UIControlStateSelected)];
        [playBtn addTarget:self action:@selector(playRecord) forControlEvents:(UIControlEventTouchUpInside)];
        playBtn.backgroundColor = [UIColor blueColor];
        [_playView addSubview:playBtn];
        
        self.playSlider = [[UISlider alloc] initWithFrame:CGRectMake(100, 0, SCREEN_WIDTH-100, 60)];
//        self.slider.center = CGPointMake(kControlBarCenterX, kControlBarCenterY + 10);
        self.playSlider.minimumTrackTintColor = [UIColor blueColor];
        [self.playSlider addTarget:self action:@selector(progressAction:) forControlEvents:UIControlEventValueChanged];
        self.playSlider.minimumValue = 0.0;
        self.playSlider.maximumValue = 1.0;
        //将滑动条加入到控制器上
        [_playView addSubview:self.playSlider];
        
        textLab = [[UILabel alloc] init];
        textLab.text = @"";
        textLab.frame = CGRectMake(100, 50, SCREEN_WIDTH - 120, 30);
        textLab.textAlignment = NSTextAlignmentCenter;
        [_playView addSubview:textLab];
    }
    return _playView;
}

#pragma mark - 音频文件拼接
-(void)fileSynthesis
{
    NSString * path1 = [[self recordCacheDirectory] stringByAppendingPathComponent:self.dataArr[0]];
    NSString * path2 = [[self recordCacheDirectory] stringByAppendingPathComponent:self.dataArr[1]];
//    [self addAudio:path1 toAudio:path2];
    [self pieceFileA:path1 withFileB:path2];

}


#pragma mark 音频的拼接：追加某个音频在某个音频的后面
/**
 音频的拼接  这个能将mp3生成为m4a 无法生成mp3
 
 @param fromPath 前段音频路径
 @param toPath 后段音频路径
 */
-(void)addAudio:(NSString *)fromPath toAudio:(NSString *)toPath {
    
    NSString * outputPath = [[self recordCacheDirectory] stringByAppendingPathComponent:@"out.m4a"];
    
    // 1. 获取两个音频源
    AVURLAsset *audioAsset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:fromPath]];
    AVURLAsset *audioAsset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:toPath]];
    
    // 2. 获取两个音频素材中的素材轨道
    AVAssetTrack *audioAssetTrack1 = [[audioAsset1 tracksWithMediaType:AVMediaTypeAudio] firstObject];
    AVAssetTrack *audioAssetTrack2 = [[audioAsset2 tracksWithMediaType:AVMediaTypeAudio] firstObject];
    
    // 3. 向音频合成器, 添加一个空的素材容器
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:0];
    
    // 4. 向素材容器中, 插入音轨素材
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset2.duration) ofTrack:audioAssetTrack2 atTime:kCMTimeZero error:nil];
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset1.duration) ofTrack:audioAssetTrack1 atTime:audioAsset2.duration error:nil];
    
    // 5. 根据合成器, 创建一个导出对象, 并设置导出参数
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetAppleM4A];
    session.outputURL = [NSURL fileURLWithPath:outputPath];
    session.outputFileType = AVFileTypeAppleM4A;
    
    // 6. 开始导出数据
//    __weak typeof(self) weakSelf = self;
    [session exportAsynchronouslyWithCompletionHandler:^{
        
        AVAssetExportSessionStatus status = session.status;

        [self.dataArr addObject:@"out.m4a"];
        [self.tableView reloadData];
        
        NSLog(@"");
    }];
    
}

// 文件拼接
- (BOOL)pieceFileA:(NSString *)filePathA withFileB:(NSString *)filePathB {
    //把文件复制到带合成文件路径
    NSString *synthesisFilePath = [[self recordCacheDirectory] stringByAppendingPathComponent:@"new.aac"];
    [[NSFileManager defaultManager] copyItemAtPath:filePathA toPath:synthesisFilePath error:nil];
    
    // 更新的方式读取文件A
    NSFileHandle *handleA = [NSFileHandle fileHandleForUpdatingAtPath:synthesisFilePath];
    [handleA seekToEndOfFile];
    
    NSDictionary *fileBDic =
    [[NSFileManager defaultManager] attributesOfItemAtPath:filePathB
                                                     error:nil];
    long long fileSizeB = fileBDic.fileSize;
    
    // 大于xM分片拼接xM
    if (fileSizeB > KFILESIZE) {
        
        // 分片
        long long pieces = fileSizeB / KFILESIZE; // 整片
        long long let = fileSizeB % KFILESIZE;    // 剩余片
        
        long long sizes = pieces;
        // 有余数
        if (let > 0) {
            // 加多一片
            sizes += 1;
        }
        
        NSFileHandle *handleB = [NSFileHandle fileHandleForReadingAtPath:filePathB];
        for (int i = 0; i < sizes; i++) {
            
            [handleB seekToFileOffset:i * KFILESIZE];
            NSData *tmp = [handleB readDataOfLength:KFILESIZE];
            [handleA writeData:tmp];
        }
        
        [handleB synchronizeFile];
        
        // 大于xM分片读xM(最后一片可能小于xM)
    } else {
        
        [handleA writeData:[NSData dataWithContentsOfFile:filePathB]];
    }
    
    [handleA synchronizeFile];
    
    // 将B文件删除
    //    [[NSFileManager defaultManager] removeItemAtPath:filePathB error:nil];
    [self.dataArr addObject:@"new.aac"];
    [self.tableView reloadData];
    return YES;
}


@end

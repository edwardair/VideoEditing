//
//  MediaManager.m
//  AddBackgroundMusic
//
//  Created by Shelin on 15/11/25.
//  Copyright © 2015年 GreatGate. All rights reserved.
//

#import "MediaManager.h"
#import <AVFoundation/AVFoundation.h>



@implementation MediaManager

+ (void)addBackgroundMiusicWithVideoUrlStr:(NSURL *)videoUrl audioUrl:(NSURL *)audioUrl andCaptureVideoWithRange:(NSRange)videoRange completion:(MixcompletionBlock)completionHandle {

    //AVURLAsset此类主要用于获取媒体信息，包括视频、声音等
    AVURLAsset* audioAsset = [[AVURLAsset alloc] initWithURL:audioUrl options:nil];
    AVURLAsset* videoAsset = [[AVURLAsset alloc] initWithURL:videoUrl options:nil];
    
    //创建AVMutableComposition对象来添加视频音频资源的AVMutableCompositionTrack
    AVMutableComposition* mixComposition = [AVMutableComposition composition];

    //CMTimeRangeMake(start, duration),start起始时间，duration时长，都是CMTime类型
    //CMTimeMake(int64_t value, int32_t timescale)，返回CMTime，value视频的一个总帧数，timescale是指每秒视频播放的帧数，视频播放速率，（value / timescale）才是视频实际的秒数时长，timescale一般情况下不改变，截取视频长度通过改变value的值
    //CMTimeMakeWithSeconds(Float64 seconds, int32_t preferredTimeScale)，返回CMTime，seconds截取时长（单位秒），preferredTimeScale每秒帧数
    
    //开始位置startTime
    CMTime startTime = CMTimeMakeWithSeconds(videoRange.location, videoAsset.duration.timescale);
    //截取长度videoDuration
    CMTime videoDuration = CMTimeMakeWithSeconds(videoRange.length, videoAsset.duration.timescale);
    
    CMTimeRange videoTimeRange = CMTimeRangeMake(startTime, videoDuration);
    
    //视频采集compositionVideoTrack
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
#warning 避免数组越界 tracksWithMediaType 找不到对应的文件时候返回空数组
    //TimeRange截取的范围长度
    //ofTrack来源
    //atTime插放在视频的时间位置
    [compositionVideoTrack insertTimeRange:videoTimeRange ofTrack:([videoAsset tracksWithMediaType:AVMediaTypeVideo].count>0) ? [videoAsset tracksWithMediaType:AVMediaTypeVideo].firstObject : nil atTime:kCMTimeZero error:nil];
    
    
    
    
    
    /*
     //视频声音采集(也可不执行这段代码不采集视频音轨，合并后的视频文件将没有视频原来的声音)
     
     AVMutableCompositionTrack *compositionVoiceTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
     
     [compositionVoiceTrack insertTimeRange:videoTimeRange ofTrack:([videoAsset tracksWithMediaType:AVMediaTypeAudio].count>0)?[videoAsset tracksWithMediaType:AVMediaTypeAudio].firstObject:nil atTime:kCMTimeZero error:nil];
     
     */
    
    
    //声音长度截取范围==视频长度
    CMTimeRange audioTimeRange = CMTimeRangeMake(kCMTimeZero, videoDuration);
    
    //音频采集compositionCommentaryTrack
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    [compositionAudioTrack insertTimeRange:audioTimeRange ofTrack:([audioAsset tracksWithMediaType:AVMediaTypeAudio].count > 0) ? [audioAsset tracksWithMediaType:AVMediaTypeAudio].firstObject : nil atTime:kCMTimeZero error:nil];
    
    //AVAssetExportSession用于合并文件，导出合并后文件，presetName文件的输出类型
    AVAssetExportSession *assetExportSession = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPreset640x480];
    
    {//水印
        
        AVMutableVideoComposition *mutableVideoComposition = [AVMutableVideoComposition videoComposition];
        mutableVideoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        mutableVideoComposition.renderSize = mixComposition.naturalSize;
        
        AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoDuration);
        
        AVAssetTrack *videoTrack = [mixComposition tracksWithMediaType:AVMediaTypeVideo][0];
        AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        passThroughInstruction.layerInstructions = @[passThroughLayer];
        mutableVideoComposition.instructions = @[passThroughInstruction];
        
        CALayer *exportWatermarkLayer = [self copyWatermarkLayer:nil];
        CALayer *parentLayer = [CALayer layer];
        CALayer *videoLayer = [CALayer layer];
        parentLayer.frame = CGRectMake(0, 0, mixComposition.naturalSize.width, mixComposition.naturalSize.height);
        videoLayer.frame = CGRectMake(0, 0, mixComposition.naturalSize.width, mixComposition.naturalSize.height);
        [parentLayer addSublayer:videoLayer];
        exportWatermarkLayer.position = CGPointMake(mixComposition.naturalSize.width/2, mixComposition.naturalSize.height/2);
        [parentLayer addSublayer:exportWatermarkLayer];
        mutableVideoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
        
        
        
        assetExportSession.videoComposition = mutableVideoComposition;
    }
    
    NSString *outPutPath = [NSTemporaryDirectory() stringByAppendingPathComponent:MediaFileName];
    //混合后的视频输出路径
    NSURL *outPutUrl = [NSURL fileURLWithPath:outPutPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:outPutPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:outPutPath error:nil];
    }
    
    //输出视频格式 AVFileTypeMPEG4 AVFileTypeQuickTimeMovie...
    assetExportSession.outputFileType = AVFileTypeQuickTimeMovie;
//    NSArray *fileTypes = assetExportSession.
    
    assetExportSession.outputURL = outPutUrl;
    //输出文件是否网络优化
    assetExportSession.shouldOptimizeForNetworkUse = YES;
    
    [assetExportSession exportAsynchronouslyWithCompletionHandler:^{
        completionHandle();
    }];
}
+ (CALayer*)copyWatermarkLayer:(UILabel*)inputLabel
{
    inputLabel = [[UILabel alloc]init];
    inputLabel.textColor = [UIColor redColor];
    inputLabel.text = @"哈哈123";
    inputLabel.font = [UIFont systemFontOfSize:100.f];
    [inputLabel sizeToFit];
    
    CALayer *exportWatermarkLayer = [CALayer layer];
    CATextLayer *titleLayer = [CATextLayer layer];
//    CATextLayer *inputTextLayer = (id)[inputLayer sublayers][0];
    titleLayer.string = inputLabel.text;
    titleLayer.foregroundColor = inputLabel.textColor.CGColor;
    titleLayer.font = (__bridge CFTypeRef)inputLabel.font;
    UIFont *font = inputLabel.font;
    //set layer font
    CFStringRef fontName = (__bridge CFStringRef)font.fontName;
    CGFontRef fontRef = CGFontCreateWithFontName(fontName);
    titleLayer.font = fontRef;
    titleLayer.fontSize = font.pointSize;
    CGFontRelease(fontRef);
    
    titleLayer.shadowOpacity = inputLabel.layer.shadowOpacity;
    titleLayer.alignmentMode = @"center";
    titleLayer.bounds = inputLabel.bounds;
    titleLayer.backgroundColor = [UIColor colorWithRed:1.000 green:1.000 blue:0.000 alpha:0.500].CGColor;
    [exportWatermarkLayer addSublayer:titleLayer];
    
    {//添加动画
        CABasicAnimation *positionAnima = [CABasicAnimation animationWithKeyPath:@"position.y"];
        positionAnima.duration = 10;
        positionAnima.fromValue = @(0);
        positionAnima.toValue = @(500);
        positionAnima.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        positionAnima.repeatCount = 0;
        //            positionAnima.repeatDuration = 2;
        positionAnima.removedOnCompletion = NO;
        positionAnima.beginTime = AVCoreAnimationBeginTimeAtZero;
//        positionAnima.fillMode = kCAFillModeForwards;
        [titleLayer addAnimation:positionAnima forKey:@"test"];
    }
    
    return exportWatermarkLayer;
}

+ (CGFloat)getMediaDurationWithMediaUrl:(NSString *)mediaUrlStr {
    
    NSURL *mediaUrl = [NSURL URLWithString:mediaUrlStr];
    AVURLAsset *mediaAsset = [[AVURLAsset alloc] initWithURL:mediaUrl options:nil];
    CMTime duration = mediaAsset.duration;
    
    return duration.value / duration.timescale;    
}

+ (NSString *)getMediaFilePath {
    
    return [NSTemporaryDirectory() stringByAppendingPathComponent:MediaFileName];
    
}

@end

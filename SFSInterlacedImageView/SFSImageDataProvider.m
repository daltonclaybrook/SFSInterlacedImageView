//
//  SFSImageDataProvider.m
//  SFSInterlacedImageView
//
//  Created by Dalton Claybrook on 10/20/13.
//  Copyright (c) 2013 Space Factory Studios. All rights reserved.
//

#import "SFSImageDataProvider.h"

typedef struct {
    uint32_t width;
    uint32_t height;
    uint8_t bitDepth;
    uint8_t colorType;
    uint8_t compressionMethod;
    uint8_t filterMethod;
    uint8_t interlaceMethod;
} IHDRChunk;

@interface SFSImageDataProvider () <NSURLConnectionDataDelegate> {
    NSMutableData *_mutableData;
}

@property (nonatomic, strong) NSURLConnection *activeConnection;
@property (nonatomic) BOOL interlacingConfirmed;

@property (nonatomic, assign) NSUInteger dataIndex;
@property (nonatomic, assign) IHDRChunk ihdrChunk;
@property (nonatomic, assign) NSUInteger idatChunksRead;
@property (nonatomic, assign) NSUInteger passesComplete;

@end

@implementation SFSImageDataProvider

@synthesize imageData = _mutableData;

#pragma mark - Initializers

- (instancetype)initWithImageURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        _imageURL = url;
        _mutableData = [[NSMutableData alloc] init];
    }
    return self;
}

#pragma mark - Public

- (void)start
{
    NSAssert(_imageURL, @"Image URL must not be nil");
    
    _interlacingConfirmed = NO;
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.imageURL];
    _activeConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)cancel
{
    [self.activeConnection cancel];
    self.activeConnection = nil;
}

#pragma mark - Private

- (NSError *)advanceDataIndexPastChunks
{
    if (self.imageData.length < 8) return nil;      // Haven't received the first 8 bytes, which is the signature
    if (self.dataIndex == 0 && ![self readSignature])
    {
        return [[NSError alloc] init];              // Change this.
    }
    
    NSError *error = nil;
    while ([self readNextChunkWithError:&error]);
    return error;
}

- (BOOL)readSignature
{
    uint8_t signature[] = { 137, 80, 78, 71, 13, 10, 26, 10 };  // PNG Signature
    for (int i=0; i<8; i++)
    {
        uint8_t byte;
        [self.imageData getBytes:&byte range:NSMakeRange(i, 1)];
        if (byte != signature[i])
        {
            return NO;
        }
    }
    
    self.dataIndex = 8;
    return YES;
}

- (BOOL)readNextChunkWithError:(NSError **)error
{
    uint32_t chunkLength;
    size_t lengthByteSize = sizeof(chunkLength);
    size_t chunkSignatureLength = 4;    // Chunk signatre, e.g. IHDR always has a length of 4
    size_t cyclicRedundancyCodeLenth = 4;
    if (self.imageData.length < self.dataIndex + lengthByteSize)
    {
        return NO;
    }
    
    [self.imageData getBytes:&chunkLength range:NSMakeRange(self.dataIndex, lengthByteSize)];
    chunkLength = CFSwapInt32HostToBig(chunkLength);
    if (self.imageData.length < self.dataIndex + lengthByteSize + chunkSignatureLength + chunkLength)
    {
        return NO;
    }
    self.dataIndex += lengthByteSize;
    
    uint32_t ihdrSignature = (73 << 24) | (72 << 16) | (68 << 8) | 82;
    uint32_t idatSignature = (73 << 24) | (68 << 16) | (65 << 8) | 84;
    
    uint32_t chunkSignature;
    [self.imageData getBytes:&chunkSignature range:NSMakeRange(self.dataIndex, chunkSignatureLength)];
    chunkSignature = CFSwapInt32HostToBig(chunkSignature);
    self.dataIndex += chunkSignatureLength;
    
    if (chunkSignature == ihdrSignature)
    {
        [self parseIHDRChunk];
        if (self.ihdrChunk.interlaceMethod == 0)
        {
            *error = [[NSError alloc] init];    // Change this
            return NO;
        }
    }
    else if (chunkSignature == idatSignature)   //This is the chunk that contains image data
    {
        self.dataIndex += chunkLength;
        self.idatChunksRead++;
        [self evaluateAdam7];
    }
    else                                        // Simply skip this chunk
    {
        self.dataIndex += chunkLength;
    }
    
    self.dataIndex += cyclicRedundancyCodeLenth;
    return YES;
}

- (void)parseIHDRChunk
{
    [self.imageData getBytes:&_ihdrChunk.width range:NSMakeRange(self.dataIndex, sizeof(_ihdrChunk.width))];
    _ihdrChunk.width = CFSwapInt32HostToBig(_ihdrChunk.width);
    self.dataIndex += sizeof(_ihdrChunk.width);
    
    [self.imageData getBytes:&_ihdrChunk.height range:NSMakeRange(self.dataIndex, sizeof(_ihdrChunk.height))];
    _ihdrChunk.height = CFSwapInt32HostToBig(_ihdrChunk.height);
    self.dataIndex += sizeof(_ihdrChunk.height);
    
    [self.imageData getBytes:&_ihdrChunk.bitDepth range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.colorType range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.compressionMethod range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.filterMethod range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
    
    [self.imageData getBytes:&_ihdrChunk.interlaceMethod range:NSMakeRange(self.dataIndex, 1)];
    self.dataIndex++;
}

- (void)evaluateAdam7
{
    uint32_t pass1ChunkCount = ceil(self.ihdrChunk.width / 8.0f) * ceil(self.ihdrChunk.height / 8.0f);
    uint32_t pass2ChunkCount = ceil((self.ihdrChunk.width-4) / 8.0f) * ceil(self.ihdrChunk.height / 8.0f) + pass1ChunkCount;
    uint32_t pass3ChunkCount = ceil(self.ihdrChunk.width / 4.0f) * ceil((self.ihdrChunk.height-4) / 8.0f) + pass2ChunkCount;
    uint32_t pass4ChunkCount = ceil((self.ihdrChunk.width-2) / 4.0f) * ceil(self.ihdrChunk.height / 4.0f) + pass3ChunkCount;
    uint32_t pass5ChunkCount = ceil(self.ihdrChunk.width / 2.0f) * ceil((self.ihdrChunk.height-2) / 4.0f) + pass4ChunkCount;
    uint32_t pass6ChunkCount = ceil((self.ihdrChunk.width-1) / 2.0f) * ceil(self.ihdrChunk.height / 2.0f) + pass5ChunkCount;
    uint32_t pass7ChunkCount = self.ihdrChunk.width * self.ihdrChunk.height;
    
    if (self.idatChunksRead >= pass1ChunkCount && self.passesComplete < 1) self.passesComplete = 1;
    if (self.idatChunksRead >= pass2ChunkCount && self.passesComplete < 2) self.passesComplete = 2;
    if (self.idatChunksRead >= pass3ChunkCount && self.passesComplete < 3) self.passesComplete = 3;
    if (self.idatChunksRead >= pass4ChunkCount && self.passesComplete < 4) self.passesComplete = 4;
    if (self.idatChunksRead >= pass5ChunkCount && self.passesComplete < 5) self.passesComplete = 5;
    if (self.idatChunksRead >= pass6ChunkCount && self.passesComplete < 6) self.passesComplete = 6;
    if (self.idatChunksRead >= pass7ChunkCount && self.passesComplete < 7) self.passesComplete = 7;
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [_mutableData setLength:0];
    self.dataIndex = 0;
    self.idatChunksRead = 0;
    self.passesComplete = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_mutableData appendData:data];
    NSError *error = [self advanceDataIndexPastChunks];
    if (error)
    {
        [self.activeConnection cancel];
        if ([self.delegate respondsToSelector:@selector(imageDataProvider:failedWithError:)])
        {
            [self.delegate imageDataProvider:self failedWithError:error];
        }
    }
    
//    for (int i=0; i<data.length; i++)
//    {
//        uint8_t byte;
//        uint32_t size;
//        [data getBytes:&byte range:NSMakeRange(i, 1)];
//        [data getBytes:&size range:NSMakeRange(i, 4)];
//        size = CFSwapInt32HostToBig(size);
//        NSLog(@"%i, %c, %i", byte, byte, size);
//    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    
}

@end

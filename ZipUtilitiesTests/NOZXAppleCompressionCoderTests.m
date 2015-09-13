//
//  NOZXAppleCompressionCoderTests.m
//  ZipUtilities
//
//  Created by Nolan O'Brien on 9/11/15.
//  Copyright © 2015 NSProgrammer. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ZipUtilities.h"
#import "NOZXAppleCompressionCoder.h"

#if COMPRESSION_LIB_AVAILABLE

@interface NOZXAppleCompressionCoderTests : XCTestCase
@end

@implementation NOZXAppleCompressionCoderTests

+ (void)setUp
{
    if ([NOZXAppleCompressionCoder isSupported]) {

        // LZMA

        NOZUpdateCompressionMethodEncoder(NOZCompressionMethodLZMA, [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZMA]);
        NOZUpdateCompressionMethodDecoder(NOZCompressionMethodLZMA, [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZMA]);

        // LZ4

        NOZUpdateCompressionMethodEncoder((NOZCompressionMethod)COMPRESSION_LZ4, [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZ4]);
        NOZUpdateCompressionMethodDecoder((NOZCompressionMethod)COMPRESSION_LZ4, [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZ4]);

        // Apple LZFSE

        NOZUpdateCompressionMethodEncoder((NOZCompressionMethod)COMPRESSION_LZFSE, [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_LZFSE]);
        NOZUpdateCompressionMethodDecoder((NOZCompressionMethod)COMPRESSION_LZFSE, [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_LZFSE]);

    }
}

+ (void)tearDown
{
    if ([NOZXAppleCompressionCoder isSupported]) {

        // LZMA

        NOZUpdateCompressionMethodEncoder(NOZCompressionMethodLZMA, nil);
        NOZUpdateCompressionMethodDecoder(NOZCompressionMethodLZMA, nil);

        // LZ4

        NOZUpdateCompressionMethodEncoder((NOZCompressionMethod)COMPRESSION_LZ4, nil);
        NOZUpdateCompressionMethodDecoder((NOZCompressionMethod)COMPRESSION_LZ4, nil);

        // Apple LZFSE

        NOZUpdateCompressionMethodEncoder((NOZCompressionMethod)COMPRESSION_LZFSE, nil);
        NOZUpdateCompressionMethodDecoder((NOZCompressionMethod)COMPRESSION_LZFSE, nil);

    }
}

- (void)runCodingWithMethod:(NOZCompressionMethod)method
{
    if (![NOZXAppleCompressionCoder isSupported]) {
        return;
    }

    NSString *zipDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:zipDirectory withIntermediateDirectories:YES attributes:NULL error:NULL];
    NSString *sourceFile = [[NSBundle bundleForClass:[self class]] pathForResource:@"Aesop" ofType:@"txt"];
    NSData *sourceData = [NSData dataWithContentsOfFile:sourceFile];
    __block NSData *unzippedData = nil;

    // Zip

    NOZFileZipEntry *entry = [[NOZFileZipEntry alloc] initWithFilePath:sourceFile];
    entry.compressionMethod = method;
    NSString *zipFileName = [NSString stringWithFormat:@"Aesop.%u.zip", method];
    NOZZipper *zipper = [[NOZZipper alloc] initWithZipFile:[zipDirectory stringByAppendingPathComponent:zipFileName]];
    XCTAssertTrue([zipper openWithMode:NOZZipperModeCreate error:NULL]);
    XCTAssertTrue([zipper addEntry:entry progressBlock:NULL error:NULL]);
    XCTAssertTrue([zipper closeAndReturnError:NULL]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:zipper.zipFilePath]);

    // Unzip

    NOZUnzipper *unzipper = [[NOZUnzipper alloc] initWithZipFile:zipper.zipFilePath];
    XCTAssertTrue([unzipper openAndReturnError:NULL]);
    XCTAssertTrue([unzipper readCentralDirectoryAndReturnError:NULL]);
    [unzipper enumerateManifestEntriesUsingBlock:^(NOZCentralDirectoryRecord *record, NSUInteger index, BOOL *stop) {
        XCTAssertTrue([unzipper saveRecord:record toDirectory:zipDirectory shouldOverwrite:YES progressBlock:NULL error:NULL]);
        NSString *unzippedFilePath = [zipDirectory stringByAppendingPathComponent:record.name];
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:unzippedFilePath]);
        if ([record.name isEqualToString:sourceFile.lastPathComponent]) {
            unzippedData = [NSData dataWithContentsOfFile:unzippedFilePath];
        }
    }];
    XCTAssertTrue([unzipper closeAndReturnError:NULL]);
    XCTAssertEqualObjects(unzippedData, sourceData);

    // Cleanup

    [[NSFileManager defaultManager] removeItemAtPath:zipDirectory error:NULL];
}

- (void)testDeflate
{

    id<NOZCompressionEncoder> originalEncoder = NOZEncoderForCompressionMethod(NOZCompressionMethodDeflate);
    id<NOZCompressionDecoder> originalDecoder = NOZDecoderForCompressionMethod(NOZCompressionMethodDeflate);

    // Both custom

    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodDeflate, [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_ZLIB]);
    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodDeflate, [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_ZLIB]);

    [self runCodingWithMethod:NOZCompressionMethodDeflate];

    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodDeflate, originalEncoder);
    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodDeflate, originalDecoder);

    // Both original

    [self runCodingWithMethod:NOZCompressionMethodDeflate];

    // Original Encoder / Custom Decoder

    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodDeflate, [NOZXAppleCompressionCoder decoderWithAlgorithm:COMPRESSION_ZLIB]);

    [self runCodingWithMethod:NOZCompressionMethodDeflate];

    NOZUpdateCompressionMethodDecoder(NOZCompressionMethodDeflate, originalDecoder);

    // Custom Encoder / Original Decoder

    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodDeflate, [NOZXAppleCompressionCoder encoderWithAlgorithm:COMPRESSION_ZLIB]);

    [self runCodingWithMethod:NOZCompressionMethodDeflate];

    NOZUpdateCompressionMethodEncoder(NOZCompressionMethodDeflate, originalEncoder);

}

- (void)testLZMACoding
{
    [self runCodingWithMethod:NOZCompressionMethodLZMA];
}

- (void)testLZ4Coding
{
    [self runCodingWithMethod:(NOZCompressionMethod)COMPRESSION_LZ4];
}

- (void)testLZFSECoding
{
    [self runCodingWithMethod:(NOZCompressionMethod)COMPRESSION_LZFSE];
}

@end

#endif

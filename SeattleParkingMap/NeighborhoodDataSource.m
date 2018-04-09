//
//  NeighborhoodDataSource.m
//  SeattleParkingMap
//
//  Created by Marc on 3/21/18.
//  Copyright © 2018 Tap Light Software. All rights reserved.
//

#import "NeighborhoodDataSource.h"
#import "Neighborhood.h"

#define SPMNeighborhoodsURL @"https://web6.seattle.gov/SDOT/SeattleParkingMap/avsProxy/gisavs.asmx/GetNhdSelectDS"
#define SPMNeighborhoodElement @"NHOODS"
#define SPMNeighborhoodElementName @"NAME"
#define SPMNeighborhoodElementMinX @"MinX"
#define SPMNeighborhoodElementMinY @"MinY"
#define SPMNeighborhoodElementMaxX @"MaxX"
#define SPMNeighborhoodElementMaxY @"MaxY"

@interface Neighborhood ()

@property (nonatomic, readwrite) NSString *name;
@property (nonatomic) NSNumber *XMin;
@property (nonatomic) NSNumber *XMax;
@property (nonatomic) NSNumber *YMin;
@property (nonatomic) NSNumber *YMax;

@end

@interface NeighborhoodDataSource () <NSXMLParserDelegate>

@property (nonatomic, copy, readwrite) NSArray <Neighborhood *> *neighborhoods;
@property (nonatomic, readwrite) NSDictionary <NSString *, NSArray *> *alphabeticallySectionedNeighborhoods;
@property (nonatomic, readwrite) SPMLoadingState state;

@property (nonatomic) NSMutableArray *parsedNeighborhoods;
@property (nonatomic) Neighborhood *currentNeighborhood;
@property (nonatomic) NSString *currentElement;
@property (nonatomic) NSMutableString *currentElementValue;

@end

@implementation NeighborhoodDataSource

#pragma mark - API

- (void)loadNeighboorhoodsWithCompletionHandler:(void (^)(BOOL success))completionHandler;
{
    if (self.state == SPMStateLoading)
    {
        if (completionHandler)
        {
            completionHandler(NO);
        }
        return;
    }

    self.state = SPMStateLoading;

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:SPMNeighborhoodsURL]
                                             cachePolicy:NSURLRequestUseProtocolCachePolicy
                                         timeoutInterval:10];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                NSData *dataToParse;
                                                if (error || !data.length || ((NSHTTPURLResponse *)response).statusCode != 200)
                                                {
                                                    NSLog(@"Could not load neighboorhood data: %@", error);

                                                    NSError *cachedError;
                                                    NSString *filePath = [NSBundle.mainBundle pathForResource:@"Neighborhoods"
                                                                                                       ofType:@"xml"];
                                                    dataToParse = [NSData dataWithContentsOfFile:filePath
                                                                                         options:0
                                                                                           error:&cachedError];
                                                    if (!dataToParse)
                                                    {
                                                        NSLog(@"Could not read cached data: %@", cachedError);
                                                    }
                                                }
                                                else
                                                {
                                                    dataToParse = data;
                                                }

                                                [self parseData:dataToParse completionHandler:completionHandler];
                                            }];
    [task resume];
}

#pragma mark - Parser

/// Will block until completed
- (void)parseData:(NSData *)data completionHandler:(void (^)(BOOL success))completionHandler
{
//    NSParameterAssert(data);
    if (!data)
    {
        if (completionHandler)
        {
            self.state = SPMStateFailedToLoad;
            completionHandler(NO);
        }
        return;
    }

    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    [parser parse];

    NSError *error = parser.parserError;
    if (error)
    {
        NSLog(@"Error %@", error);
        if (completionHandler)
        {
            self.state = SPMStateFailedToLoad;
            completionHandler(NO);
        }
    }
    else
    {
        if (completionHandler)
        {
            self.state = SPMStateLoaded;
            completionHandler(YES);
        }
    }
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    self.currentElement = elementName;

//    SPMLog(@"didStartElement: %@", elementName);
    if ([elementName isEqualToString:SPMNeighborhoodElement])
    {
        self.currentNeighborhood = [[Neighborhood alloc] init];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.currentNeighborhood)
    {
        if ([self.currentElement isEqualToString:SPMNeighborhoodElementName] ||
            [self.currentElement isEqualToString:SPMNeighborhoodElementMinX] ||
            [self.currentElement isEqualToString:SPMNeighborhoodElementMaxX] ||
            [self.currentElement isEqualToString:SPMNeighborhoodElementMinY] ||
            [self.currentElement isEqualToString:SPMNeighborhoodElementMaxY])
        {
            if (!self.currentElementValue)
            {
                self.currentElementValue = [[NSMutableString alloc] init];
            }

            [self.currentElementValue appendString:string];
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    NSString *trimmedValue;

    if ([self.currentElement isEqualToString:SPMNeighborhoodElementName] ||
        [self.currentElement isEqualToString:SPMNeighborhoodElementMinX] ||
        [self.currentElement isEqualToString:SPMNeighborhoodElementMaxX] ||
        [self.currentElement isEqualToString:SPMNeighborhoodElementMinY] ||
        [self.currentElement isEqualToString:SPMNeighborhoodElementMaxY])
    {
        if ([self.currentElement isEqualToString:SPMNeighborhoodElementName] && [self.currentElementValue hasSuffix:@"District"])
        {
            [self.currentElementValue replaceOccurrencesOfString:@"District"
                                                      withString:@" District"
                                                         options:NSBackwardsSearch
                                                           range:NSMakeRange(0, self.currentElementValue.length)];
        }

        trimmedValue = [self.currentElementValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }

    if ([elementName isEqualToString:SPMNeighborhoodElementName])
    {
        self.currentNeighborhood.name = trimmedValue;
    }
    else if ([elementName isEqualToString:SPMNeighborhoodElementMinX])
    {
        self.currentNeighborhood.XMin = [NSNumber numberWithDouble:trimmedValue.doubleValue];
    }
    else if ([elementName isEqualToString:SPMNeighborhoodElementMaxX])
    {
        self.currentNeighborhood.XMax = [NSNumber numberWithDouble:trimmedValue.doubleValue];
    }
    else if ([elementName isEqualToString:SPMNeighborhoodElementMinY])
    {
        self.currentNeighborhood.YMin = [NSNumber numberWithDouble:trimmedValue.doubleValue];
    }
    else if ([elementName isEqualToString:SPMNeighborhoodElementMaxY])
    {
        self.currentNeighborhood.YMax = [NSNumber numberWithDouble:trimmedValue.doubleValue];
    }
    else if ([elementName isEqualToString:SPMNeighborhoodElement])
    {
        NSAssert(self.currentNeighborhood != nil, @"Missing current neighborhood");
        NSAssert(self.currentNeighborhood.XMin != nil, @"Missing XMin");
        NSAssert(self.currentNeighborhood.XMax != nil, @"Missing XMax");
        NSAssert(self.currentNeighborhood.YMin != nil, @"Missing YMin");
        NSAssert(self.currentNeighborhood.YMax != nil, @"Missing YMax");

        if (self.currentNeighborhood.XMin != nil &&
            self.currentNeighborhood.XMax != nil &&
            self.currentNeighborhood.YMin != nil &&
            self.currentNeighborhood.YMax != nil)
        {
            if (!self.parsedNeighborhoods)
            {
                self.parsedNeighborhoods = [[NSMutableArray alloc] initWithCapacity:25];
            }

            [self.parsedNeighborhoods addObject:self.currentNeighborhood];
        }
        else
        {
            NSLog(@"Could not add neighborhood: %@", self.currentNeighborhood);
        }

        self.currentNeighborhood = nil;
    }

    self.currentElementValue = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
    self.currentNeighborhood = nil;
    self.currentElement = nil;
    self.currentElementValue = nil;

    NSUInteger hoodsCount = _parsedNeighborhoods.count;
    NSMutableDictionary *firstLetters = [[NSMutableDictionary alloc] initWithCapacity:hoodsCount];

    NSArray <NSString *> *names = [_parsedNeighborhoods valueForKey:@"name"];

    for (NSUInteger i = 0; i < hoodsCount; i++) {
        NSString *initial = [names[i] substringWithRange:NSMakeRange(0, 1)];

        NSMutableArray *array = [firstLetters objectForKey:initial];
        if (!array)
        {
            array = [[NSMutableArray alloc] initWithCapacity:1];
            [firstLetters setObject:array
                             forKey:initial];
        }

        [array addObject:_parsedNeighborhoods[i]];
    }

    self.alphabeticallySectionedNeighborhoods = [firstLetters copy];

    self.neighborhoods = _parsedNeighborhoods;
    _parsedNeighborhoods = nil;
}

@end

//
//  NSString+QueryItems.m
//  XXTExplorer
//
//  Created by Zheng on 17/09/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "NSString+QueryItems.h"

@implementation NSString (QueryItems)

- (NSDictionary *)queryItems {
    NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
    NSArray *urlQuery = [self componentsSeparatedByString:@"&"];
    for (NSString *keyValuePair in urlQuery)
    {
        NSArray *pairComponents = [keyValuePair componentsSeparatedByString:@"="];
        NSString *key = [[pairComponents firstObject] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *value = [[pairComponents lastObject] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (key && value) {
            [queryStringDictionary setObject:value forKey:key];
        }
    }
    return [queryStringDictionary copy];
}

@end

//
//  EntitiesConverter.h
//

#import <Foundation/Foundation.h>


@interface EntitiesConverter : NSObject <NSXMLParserDelegate> {
    NSMutableString *resultString;
}

@property (nonatomic, retain) NSMutableString *resultString;

- (NSString *)convertEntiesInString:(NSString *)string;
@end
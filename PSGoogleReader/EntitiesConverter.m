//
//  EntitiesConverter.m
//

#import "EntitiesConverter.h"


@implementation EntitiesConverter

@synthesize resultString;

- (id)init {
	if (([super init])) {
		resultString = [[NSMutableString alloc] init];
	}
	
	return self;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	[self.resultString appendString:string];
}

- (NSString *)convertEntiesInString:(NSString *)string {
	[self.resultString setString:@""];
	if (string == nil) {
		NSLog(@"ERROR : Parameter string is nil");
	}
	NSString *xmlString = [NSString stringWithFormat:@"<d>%@</d>", string];
	NSData *data = [xmlString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	NSXMLParser *xmlParser = [[[NSXMLParser alloc] initWithData:data] autorelease];
	[xmlParser setDelegate:self];
	[xmlParser parse];
	return [NSString stringWithFormat:@"%@", resultString];
}

- (void)dealloc {
	[resultString release];
	[super dealloc];
}
@end

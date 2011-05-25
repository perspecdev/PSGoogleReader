//
//  TODO: Does everything work fine with non-Western characters?
//  TODO: Switch to OAuth for login
//
//  PSGoogleReader.m
//  PSGoogleReader
//
//  Created by Daniel Isenhower ( daniel@perspecdev.com ).
//  Copyright 2011 PerspecDev Solutions, LLC. All rights reserved.
//

/*
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 * Neither the name of the author nor the names of its contributors may be used
 to endorse or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define kClientName @"YourClientNameHere"
#define kReadingListBatchSize 50

#import "PSGoogleReader.h"
#import "JSON/JSON.h"
#import "EntitiesConverter.h"
#import "RegexKitLite.h"


@interface PSGoogleReader ()

@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *unixTimeCutoff;
@property (nonatomic, retain) NSString *excludeTarget;
@property (nonatomic, retain) NSString *numResults;
@property (nonatomic, retain) NSString *continuationString;
@property (nonatomic, retain) NSString *sortOrder;
@property (nonatomic, retain) NSString *itemIdentifier;
@property (nonatomic, retain) NSString *feedURL;
@property (nonatomic, retain) NSString *feedId;
@property (nonatomic, retain) SBJSON *json;
@property (nonatomic, retain) EntitiesConverter *entitiesConverter;
@property (nonatomic, retain) NSMutableDictionary *connectionIdentifiers;
@property (nonatomic, retain) NSMutableDictionary *responseData;
@property (nonatomic, retain) NSMutableArray *tokenSelectors;
@property (nonatomic, retain) NSMutableArray *itemsToModify;
@property (nonatomic) BOOL processingItemsToModify;
@property (nonatomic) BOOL needsLogin;

@end

@implementation PSGoogleReader

@synthesize SID;
@synthesize lastUpdate;
@synthesize gettingReadingList;
@synthesize delegate;

@synthesize token;
@synthesize username;
@synthesize password;
@synthesize unixTimeCutoff;
@synthesize excludeTarget;
@synthesize numResults;
@synthesize continuationString;
@synthesize sortOrder;
@synthesize itemIdentifier;
@synthesize feedURL;
@synthesize feedId;
@synthesize json;
@synthesize entitiesConverter;
@synthesize connectionIdentifiers;
@synthesize responseData;
@synthesize tokenSelectors;
@synthesize itemsToModify;
@synthesize processingItemsToModify;
@synthesize needsLogin;

- (id)init {
	if ((self = [super init])) {
		[self setURLFormats];
		
		self.SID = @"";
		self.lastUpdate = 0;
		self.gettingReadingList = NO;
		self.delegate = nil;
		
		self.token = @"no-token";
		self.username = @"";
		self.password = @"";
		self.unixTimeCutoff = @"";
		self.excludeTarget = @"";
		self.numResults = @"";
		self.continuationString = @"";
		self.sortOrder = @"";
		self.itemIdentifier = @"";
		self.feedURL = @"";
		self.feedId = @"";
		self.connectionIdentifiers = [NSMutableDictionary dictionaryWithCapacity:1];
		self.responseData = [NSMutableDictionary dictionaryWithCapacity:1];
		self.tokenSelectors = [NSMutableArray arrayWithCapacity:0];
		self.itemsToModify = [NSMutableArray arrayWithCapacity:0];
		self.processingItemsToModify = NO;
		self.needsLogin = YES;
		
		SBJSON *aJSON = [[SBJSON alloc] init];
		self.json = aJSON;
		[aJSON release];
		
		EntitiesConverter *anEntitiesConverter = [[EntitiesConverter alloc] init];
		self.entitiesConverter = anEntitiesConverter;
		[anEntitiesConverter release];
	}
	return self;
}

- (id)initWithSID:(NSString *)anSID {
	if ((self = [self init])) {
		self.SID = anSID;
		if (![self.SID isEqualToString:@""]) self.needsLogin = NO;
	}
	return self;
}

- (void)dealloc {
	[SID release]; SID = nil;
	
	[token release]; token = nil;
	[username release]; username = nil;
	[password release]; password = nil;
	[unixTimeCutoff release]; unixTimeCutoff = nil;
	[excludeTarget release]; excludeTarget = nil;
	[numResults release]; numResults = nil;
	[continuationString release]; continuationString = nil;
	[sortOrder release]; sortOrder = nil;
	[itemIdentifier release]; itemIdentifier = nil;
	[feedURL release]; feedURL = nil;
	[feedId release]; feedId = nil;
	[connectionIdentifiers release]; connectionIdentifiers = nil;
	[responseData release]; responseData = nil;
	[tokenSelectors release]; tokenSelectors = nil;
	[itemsToModify release]; itemsToModify = nil;
	[postFields release]; postFields = nil;
	[json release]; json = nil;
	[entitiesConverter release]; entitiesConverter = nil;
	
	[super dealloc];
}

- (void)setURLFormats {
	URLFormatGetSID = @"https://www.google.com/accounts/ClientLogin";
	URLFormatGetToken = @"http://www.google.com/reader/api/0/token";
	URLFormatQuickAddFeed = @"http://www.google.com/reader/api/0/subscription/quickadd?output=json&client=[client]&ck=[unix-time]";
	//URLFormatAddFeed = @"http://www.google.com/reader/api/0/subscription/edit?client=[your client]";
	//URLFormatEditFeed = @"http://www.google.com/reader/api/0/subscription/edit?client=[your client]";
	URLFormatRemoveFeed = @"http://www.google.com/reader/api/0/subscription/edit?output=json&client=[client]&ck=[unix-time]";
	//URLFormatSetFeedLabel = @"http://www.google.com/reader/api/0/subscription/edit?client=[client]";
	URLFormatGetUnreadCount = @"http://www.google.com/reader/api/0/unread-count?all=true&output=json&client=[client]&ck=[unix-time]";
	//URLFormatGetUserInfo = @"http://www.google.com/reader/api/0/user-info?&ck=[unix-time]&client=[client]";
	//URLFormatGetFeed = @"http://www.google.com/reader/api/0/stream/contents/[feed-id]?r=[sort-order]&xt=[exclude-target]&n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatGetLabel = @"http://www.google.com/reader/api/0/stream/contents/label/[label-name]?ot=[unix-time-cutoff]&r=[sort-order]&xt=[exclude-target]&n=[num-results]&ck=[unix-time]&client=[client]";
	URLFormatGetReadingList = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/reading-list?&r=[sort-order]&xt=[exclude-target]&n=[num-results]&c=[continuation]&ck=[unix-time]&client=[client]";
	URLFormatGetSubscriptionList = @"http://www.google.com/reader/api/0/subscription/list?output=json&client=[client]&ck=[unix-time]";
	//URLFormatGetStarred = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/starred?n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatGetBroadcasted = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/broadcast?n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatGetNotes = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/created?n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatAddTag = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatRemoveTag = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	URLFormatSetRead = @"http://www.google.com/reader/api/0/edit-tag?client=[client]&ck=[unix-time]";
	URLFormatSetNotRead = @"http://www.google.com/reader/api/0/edit-tag?client=[client]&ck=[unix-time]";
	URLFormatSetFeedRead = @"http://www.google.com/reader/api/0/mark-all-as-read?client=[client]&ck=[unix-time]";
	//URLFormatSetStarred = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatSetNotStarred = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatSetLike = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatSetNotLike = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatSetBroadcast = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatSetNotBroadcast = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatEmail = @"";
	
	NSDictionary *getSIDFields = [NSDictionary dictionaryWithObjectsAndKeys:
								  @"[email]", @"Email"
								  , @"[password]", @"Passwd"
								  , @"reader", @"service"
								  , @"[client]", @"source"
								  //, @"GOOGLE", @"accountType"
								  , nil];
	NSDictionary *quickAddFeedFields = [NSDictionary dictionaryWithObjectsAndKeys:
										@"[feed-url]", @"quickadd"
										, @"[token]", @"T"
										, nil];
	NSDictionary *setFeedLabelFields = [NSDictionary dictionaryWithObjectsAndKeys:
										@"user/-/label/[label-name]", @"a"
										, @"feed/[feed-url]", @"s"
										, @"edit", @"ac"
										, @"[token]", @"T"
										, nil];
	NSDictionary *addFeedFields = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"feed/[feed-url]", @"s"
								   , @"subscribe", @"ac"
								   , @"[feed-title]", @"t"
								   , @"[token]", @"T"
								   , nil];
	NSDictionary *editFeedFields = [NSDictionary dictionaryWithObjectsAndKeys:
									@"feed/[feed-url]", @"s"
									, @"edit", @"ac"
									, @"[feed-title]", @"t"
									, @"[token]", @"T"
									, nil];
	NSDictionary *removeFeedFields = [NSDictionary dictionaryWithObjectsAndKeys:
									  @"[feed-id]", @"s"
									  , @"unsubscribe", @"ac"
									  , @"[token]", @"T"
									  , nil];
	NSDictionary *addTagFields = [NSDictionary dictionaryWithObjectsAndKeys:
								  @"user/-/label/[tag-name]", @"a"
								  , @"true", @"async"
								  , @"feed/[feed-url]", @"s"
								  , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
								  , @"[token]", @"T"
								  , nil];
	NSDictionary *removeTagFields = [NSDictionary dictionaryWithObjectsAndKeys:
									 @"user/-/label/[tag-name]", @"r"
									 , @"true", @"async"
									 , @"feed/[feed-url]", @"s"
									 , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
									 , @"[token]", @"T"
									 , nil];
	NSDictionary *setReadFields = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"[item-identifier]", @"i"
								   , @"user/-/state/com.google/read", @"a"
								   , @"user/-/state/com.google/kept-unread", @"r"
								   , @"edit", @"ac"
								   , @"[token]", @"T"
								   , nil];
	NSDictionary *setNotReadFields = [NSDictionary dictionaryWithObjectsAndKeys:
									  @"[item-identifier]", @"i"
									  , @"user/-/state/com.google/read", @"r"
									  , @"user/-/state/com.google/kept-unread", @"a"
									  , @"edit", @"ac"
									  , @"[token]", @"T"
									  , nil];
	NSDictionary *setFeedReadFields = [NSDictionary dictionaryWithObjectsAndKeys:
									   @"[feed-id]", @"s"
									   , @"[unix-time-microseconds]", @"ts"
									   , @"[token]", @"T"
									   , nil];
	NSDictionary *setStarredFields = [NSDictionary dictionaryWithObjectsAndKeys:
									  @"user/-/state/com.google/starred", @"a"
									  , @"true", @"async"
									  , @"feed/[feed-url]", @"s"
									  , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
									  , @"[token]", @"T"
									  , nil];
	NSDictionary *setNotStarredFields = [NSDictionary dictionaryWithObjectsAndKeys:
										 @"user/-/state/com.google/starred", @"r"
										 , @"true", @"async"
										 , @"feed/[feed-url]", @"s"
										 , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
										 , @"[token]", @"T"
										 , nil];
	NSDictionary *setLikeFields = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"user/-/state/com.google/like", @"a"
								   , @"true", @"async"
								   , @"feed/[feed-url]", @"s"
								   , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
								   , @"[token]", @"T"
								   , nil];
	NSDictionary *setNotLikeFields = [NSDictionary dictionaryWithObjectsAndKeys:
									  @"user/-/state/com.google/like", @"r"
									  , @"true", @"async"
									  , @"feed/[feed-url]", @"s"
									  , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
									  , @"[token]", @"T"
									  , nil];
	NSDictionary *setBroadcastFields = [NSDictionary dictionaryWithObjectsAndKeys:
										@"user/-/state/com.google/broadcast", @"a"
										, @"true", @"async"
										, @"feed/[feed-url]", @"s"
										, @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
										, @"[token]", @"T"
										, nil];
	NSDictionary *setNotBroadcastFields = [NSDictionary dictionaryWithObjectsAndKeys:
										   @"user/-/state/com.google/broadcast", @"r"
										   , @"true", @"async"
										   , @"feed/[feed-url]", @"s"
										   , @"tag:google.com,2005:reader/item/[item-identifier]", @"i"
										   , @"[token]", @"T"
										   , nil];
	
	postFields = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
				   getSIDFields, @"getSID"
				   , quickAddFeedFields, @"quickAddFeed"
				   , setFeedLabelFields, @"setFeedLabel"
				   , addFeedFields, @"addFeed"
				   , editFeedFields, @"editFeed"
				   , removeFeedFields, @"removeFeed"
				   , addTagFields, @"addTag"
				   , removeTagFields, @"removeTag"
				   , setReadFields, @"setRead"
				   , setNotReadFields, @"setNotRead"
				   , setFeedReadFields, @"setFeedRead"
				   , setStarredFields, @"setStarred"
				   , setNotStarredFields, @"setNotStarred"
				   , setLikeFields, @"setLike"
				   , setNotLikeFields, @"setNotLike"
				   , setBroadcastFields, @"setBroadcast"
				   , setNotBroadcastFields, @"setNotBroadcast"
				   , nil] retain];
}

- (NSString *)populateURLFormatFields:(NSString *)URLFormat {
	NSString *URL = [[URLFormat copy] autorelease];
	URL = [URL stringByReplacingOccurrencesOfString:@"[email]" withString:self.username];
	URL = [URL stringByReplacingOccurrencesOfString:@"[password]" withString:self.password];
	URL = [URL stringByReplacingOccurrencesOfString:@"[unix-time-cutoff]" withString:self.unixTimeCutoff];
	URL = [URL stringByReplacingOccurrencesOfString:@"[sort-order]" withString:self.sortOrder];
	URL = [URL stringByReplacingOccurrencesOfString:@"[exclude-target]" withString:self.excludeTarget];
	URL = [URL stringByReplacingOccurrencesOfString:@"[unix-time]" withString:[NSString stringWithFormat:@"%d", (long)[[NSDate date] timeIntervalSince1970]]];
	URL = [URL stringByReplacingOccurrencesOfString:@"[unix-time-microseconds]" withString:[NSString stringWithFormat:@"%d000000", (long)[[NSDate date] timeIntervalSince1970]]];
	URL = [URL stringByReplacingOccurrencesOfString:@"[last-update-time]" withString:[NSString stringWithFormat:@"%d", (long)self.lastUpdate]];
	URL = [URL stringByReplacingOccurrencesOfString:@"[num-results]" withString:self.numResults];
	URL = [URL stringByReplacingOccurrencesOfString:@"[continuation]" withString:self.continuationString];
	URL = [URL stringByReplacingOccurrencesOfString:@"[client]" withString:kClientName];
	URL = [URL stringByReplacingOccurrencesOfString:@"[item-identifier]" withString:self.itemIdentifier];
	URL = [URL stringByReplacingOccurrencesOfString:@"[feed-url]" withString:self.feedURL];
	URL = [URL stringByReplacingOccurrencesOfString:@"[feed-id]" withString:self.feedId];
	URL = [URL stringByReplacingOccurrencesOfString:@"[token]" withString:self.token];
	
	return URL;
}

- (NSString *)getFormattedQueryStringFromDictionary:(NSDictionary *)URLFormatDictionary {
	NSMutableString *formattedQueryString = [NSMutableString stringWithString:@""];
	for (NSString *key in URLFormatDictionary) {
		[formattedQueryString appendFormat:@"%@=%@&", key, [self populateURLFormatFields:[URLFormatDictionary objectForKey:key]]];
	}
	
	return formattedQueryString;
}

- (void)startConnectionWithURL:(NSString *)URL withIdentifier:(NSString *)identifier sendCookie:(BOOL)sendCookie withPostData:(NSString *)postData {
	if (self.needsLogin && ![identifier isEqualToString:@"SID"]) {
		[self.delegate googleReaderNeedsLogin];
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
	
	if (postData != nil) {
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	if (sendCookie) {
		NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:[NSDictionary dictionaryWithObjectsAndKeys:
																   @"SID", @"Name"
																   , self.SID, @"Value"
																   , @"/", @"Path"
																   , @".google.com", @"Domain"
																   , nil]];
		NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:[NSArray arrayWithObject:cookie]];
		
		[request setAllHTTPHeaderFields:headers];
	}
	
	if (![self.SID isEqualToString:@""]) {
		[request setValue:[NSString stringWithFormat:@"GoogleLogin auth=%@", self.SID] forHTTPHeaderField:@"Authorization"];
	}
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self]; // released when connection finishes
	
	[self.responseData setObject:@"" forKey:identifier];
	[self.connectionIdentifiers setObject:identifier forKey:[NSString stringWithFormat:@"%d", [connection hash]]];
	
	[self.delegate googleReaderIncrementNetworkActivity];
}

- (void)loginWithUsername:(NSString *)aUsername withPassword:(NSString *)aPassword {
	NSString *theUsername = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aUsername, NULL, CFSTR("￼=,!$&'()*+;@?\n\"<>#\t :/"), kCFStringEncodingUTF8);
	NSString *thePassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aPassword, NULL, CFSTR("￼=,!$&'()*+;@?\n\"<>#\t :/"), kCFStringEncodingUTF8);
	self.username = theUsername;
	self.password = thePassword;
	[theUsername release];
	[thePassword release];
	
	NSString *URL = [self populateURLFormatFields:URLFormatGetSID];
	
	NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"getSID"]];
	
	[self startConnectionWithURL:URL withIdentifier:@"SID" sendCookie:NO withPostData:postData];
}

- (void)logout {
	self.SID = @"";
	self.needsLogin = YES;
	/*[queue cancelAllOperations];*/
	[self.delegate googleReaderNeedsLogin];
}

- (void)retrieveTokenWithSelectorName:(NSString *)selectorName {
	NSString *URL = [self populateURLFormatFields:URLFormatGetToken];
	
	[self.tokenSelectors addObject:selectorName];
	[self startConnectionWithURL:URL withIdentifier:@"Token" sendCookie:YES withPostData:nil];
}

- (void)retrieveReadingList {
	self.gettingReadingList = YES;
	
	self.unixTimeCutoff = [NSString stringWithFormat:@"%d", (long)[[NSDate date] timeIntervalSince1970]];
	self.sortOrder = @"d"; // descending order
	self.excludeTarget = @"user/-/state/com.google/read"; // items marked as read
	self.numResults = [NSString stringWithFormat:@"%d", kReadingListBatchSize];
	
	NSString *URL = [self populateURLFormatFields:URLFormatGetReadingList];
	
	[self startConnectionWithURL:URL withIdentifier:@"Reading List" sendCookie:YES withPostData:nil];
}

- (void)retrieveSubscriptionList {
	NSString *URL = [self populateURLFormatFields:URLFormatGetSubscriptionList];
	
	[self startConnectionWithURL:URL withIdentifier:@"Subscription List" sendCookie:YES withPostData:nil];
}

- (void)retrieveUnreadCount {
	NSString *URL = [self populateURLFormatFields:URLFormatGetUnreadCount];
	
	[self startConnectionWithURL:URL withIdentifier:@"Unread Count" sendCookie:YES withPostData:nil];
}

- (void)markAsRead:(NSString *)itemId {
	[self.itemsToModify addObject:[NSMutableDictionary dictionaryWithObject:itemId forKey:@"Mark as Read"]];
	[self processItemsToModify];
}

- (void)markAsUnread:(NSString *)itemId {
	[self.itemsToModify addObject:[NSMutableDictionary dictionaryWithObject:itemId forKey:@"Mark as Unread"]];
	[self processItemsToModify];
}

- (void)markFeedAsRead:(NSString *)aFeedId {
	[self.itemsToModify addObject:[NSMutableDictionary dictionaryWithObject:aFeedId forKey:@"Mark Feed as Read"]];
	[self processItemsToModify];
}

- (void)quickAddFeed:(NSString *)aFeedURL {
	self.feedURL = aFeedURL;
	
	[self quickAddFeedFromPresetURL];
}

- (void)quickAddFeedFromPresetURL {
	if ([self.token isEqualToString:@"no-token"]) {
		[self retrieveTokenWithSelectorName:@"quickAddFeedFromPresetURL"];
		return;
	}
	
	NSString *URL = [self populateURLFormatFields:URLFormatQuickAddFeed];
	NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"quickAddFeed"]];
	[self startConnectionWithURL:URL withIdentifier:@"Quick Add Feed" sendCookie:YES withPostData:postData];
}

- (void)removeFeed:(NSString *)aFeedId {
	self.feedId = aFeedId;
	
	[self removeFeedFromPresetId];
}

- (void)removeFeedFromPresetId {
	if ([token isEqualToString:@"no-token"]) {
		[self retrieveTokenWithSelectorName:@"removeFeedFromPresetId"];
		return;
	}
	
	NSString *URL = [self populateURLFormatFields:URLFormatRemoveFeed];
	NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"removeFeed"]];
	[self startConnectionWithURL:URL withIdentifier:@"Remove Feed" sendCookie:YES withPostData:postData];
}

- (void)processItemsToModify {
	if ([self.token isEqualToString:@"no-token"]) {
		[self retrieveTokenWithSelectorName:@"processItemsToModify"];
		return;
	}
	
	// need to make sure we only process one item at a time, since itemsToModify gets the first item deleted when the connection completes
	// otherwise we could end up requesting to modify the same item multiple times
	if (self.processingItemsToModify) return;
	self.processingItemsToModify = YES;
	
	if ([self.itemsToModify count] > 0) {
		NSString *itemId;
		NSString *actionToPerform = nil;
		for (NSString *key in [self.itemsToModify objectAtIndex:0]) {
			if ([key isEqualToString:@"retry"]) continue; // the "retry" key is set if we're retrying because the token was no good
			
			itemId = [[self.itemsToModify objectAtIndex:0] objectForKey:key];
			actionToPerform = [key retain];
			break;
		}
		
		if ([actionToPerform isEqualToString:@"Mark as Read"]) {
			NSString *URL = [self populateURLFormatFields:URLFormatSetRead];
			self.itemIdentifier = itemId;
			NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"setRead"]];
			[self startConnectionWithURL:URL withIdentifier:@"Mark as Read" sendCookie:YES withPostData:postData];
		} else if ([actionToPerform isEqualToString:@"Mark as Unread"]) {
			NSString *URL = [self populateURLFormatFields:URLFormatSetNotRead];
			self.itemIdentifier = itemId;
			NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"setNotRead"]];
			[self startConnectionWithURL:URL withIdentifier:@"Mark as Unread" sendCookie:YES withPostData:postData];
		} else if ([actionToPerform isEqualToString:@"Mark Feed as Read"]) {
			NSString *URL = [self populateURLFormatFields:URLFormatSetFeedRead];
			self.itemIdentifier = @"";
			self.feedId = itemId;
			NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"setFeedRead"]];
			[self startConnectionWithURL:URL withIdentifier:@"Mark Feed as Read" sendCookie:YES withPostData:postData];
		} else {
			self.processingItemsToModify = NO;
		}
		
		[actionToPerform release];
	} else {
		self.processingItemsToModify = NO;
	}
	
}


#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	// TODO: I think invalid SID (meaning we need to log back in) should actually only be 401.
	// But there were some problems with just checking for 401 where we needed to log back in
	// but the statusCode wasn't 401.  So just going the aggressive/safe route here...
	if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] >= 300) {
		self.needsLogin = YES;
		[self.delegate googleReaderNeedsLogin];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSString *identifier = [self.connectionIdentifiers objectForKey:[NSString stringWithFormat:@"%d", [connection hash]]];
	
	NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (dataString == nil) {
		[dataString release];
		return;
	}
	
	if (
		[identifier isEqualToString:@"SID"]
		|| [identifier isEqualToString:@"Token"]
		|| [identifier isEqualToString:@"Token Try Again"]
		|| [identifier isEqualToString:@"Subscription List"]
		|| [identifier isEqualToString:@"Unread Count"]
		|| [identifier isEqualToString:@"Reading List"]
		|| [identifier isEqualToString:@"Mark as Read"]
		|| [identifier isEqualToString:@"Mark as Unread"]
		|| [identifier isEqualToString:@"Mark Feed as Read"]
		|| [identifier isEqualToString:@"Quick Add Feed"]
		|| [identifier isEqualToString:@"Remove Feed"]
		) {
		[self.responseData setObject:[[self.responseData objectForKey:identifier] stringByAppendingString:dataString] forKey:identifier];
	}
	
	[dataString release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self.delegate googleReaderDecrementNetworkActivity];
	
	NSString *identifier = [self.connectionIdentifiers objectForKey:[NSString stringWithFormat:@"%d", [connection hash]]];
	
	if ([identifier isEqualToString:@"SID"]) {
		self.SID = @"";
		NSString *responseString = [[self.responseData objectForKey:@"SID"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSArray *components = [responseString componentsSeparatedByString:@"\n"];
		for (int i=0; i<[components count]; i++) {
			if ([[(NSString *)[components objectAtIndex:i] substringToIndex:5] isEqualToString:@"Auth="]) {
				self.SID = [(NSString *)[components objectAtIndex:i] substringFromIndex:5];
				break;
			}
		}
		
		if ([self.SID isEqualToString:@""]) {
			self.needsLogin = YES;
			[self.delegate googleReaderNeedsLogin];
		} else {
			self.needsLogin = NO;
			[self.delegate googleReaderInitializedAndReady];
		}
	} else if ([identifier isEqualToString:@"Token"] || [identifier isEqualToString:@"Token Try Again"]) {
		self.token = [[self.responseData objectForKey:identifier] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		[self.responseData setObject:@"" forKey:identifier]; // need to reset the responseData for token in case there's another call coming in right behind it
		
		if ([self.tokenSelectors count] > 0) {
			if ([self.tokenSelectors objectAtIndex:0] != nil) {
				NSString *selectorName = [self.tokenSelectors objectAtIndex:0];
				[self performSelector:NSSelectorFromString(selectorName)];
			}
		} else {
			self.token = @"";
		}
		
	} else if ([identifier isEqualToString:@"Subscription List"]) {
		NSArray *subscriptionList = [[self.json objectWithString:[[self.responseData objectForKey:identifier] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]] objectForKey:@"subscriptions"];
		[self.delegate googleReaderSubscriptionList:subscriptionList];
	} else if ([identifier isEqualToString:@"Unread Count"]) {
		//
	} else if ([identifier isEqualToString:@"Reading List"]) {
		if (!self.needsLogin) {
			NSDictionary *responseObject = [self.json objectWithString:[self.responseData objectForKey:identifier]];
			NSArray *readingList = [responseObject objectForKey:@"items"];
			if (readingList == nil) {
				//NSLog(@"%@", [self.json.errorTrace description]);
				self.gettingReadingList = NO;
				[self.delegate googleReaderCouldNotGetReadingList];
			} else {
				BOOL isLastInSync;
				self.continuationString = [responseObject objectForKey:@"continuation"];
				if (self.continuationString != nil && ![self.continuationString isEqualToString:@""]) {
					isLastInSync = NO;
					[self retrieveReadingList];
				} else {
					isLastInSync = YES;
					self.continuationString = @"";
				}
				
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					NSMutableArray *processedItems = [[NSMutableArray alloc] init];
					
					for (NSDictionary *item in readingList) {
						NSString *itemId = [item objectForKey:@"id"];
						if (itemId == nil) continue;
						
						NSNumber *published = [item objectForKey:@"published"];
						if (published == nil || [published intValue] == 0) published = [NSNumber numberWithInt:[NSDate timeIntervalSinceReferenceDate]];
						
						NSNumber *updated = [item objectForKey:@"updated"];
						if (updated == nil || [updated intValue] == 0) updated = [NSNumber numberWithInt:[published intValue]];
						
						NSString *title = [item objectForKey:@"title"];
						if (title == nil) continue;
						
						NSString *content = [[item objectForKey:@"content"] objectForKey:@"content"];
						NSString *summary = [[item objectForKey:@"summary"] objectForKey:@"content"];
						if (summary == NULL) summary = @"";
						if (content == NULL) content = [NSString stringWithFormat:@"%@", summary];
						
						NSString *feedTitle = [[item objectForKey:@"origin"] objectForKey:@"title"];
						if (feedTitle == nil) continue;
						
						title = [entitiesConverter convertEntiesInString:title];
						summary = [entitiesConverter convertEntiesInString:summary];
						content = [entitiesConverter convertEntiesInString:content];
						feedTitle = [entitiesConverter convertEntiesInString:feedTitle];
						
						NSArray *alternate = [item objectForKey:@"alternate"];
						NSString *URL = @"";
						if (alternate != nil && [alternate count] > 0) {
							NSDictionary *firstAlternate = [alternate objectAtIndex:0];
							if (firstAlternate != nil) {
								NSString *itemURL = [firstAlternate objectForKey:@"href"];
								if (itemURL != nil) {
									URL = itemURL;
								}
							}
						}
						
						NSString *streamId = [[item objectForKey:@"origin"] objectForKey:@"streamId"];
						if (streamId == nil) continue;
						
						NSString *itemFeedURL = [[item objectForKey:@"origin"] objectForKey:@"htmlUrl"];
						if (itemFeedURL == nil) continue;
						
						NSArray *categories = [item objectForKey:@"categories"];
						BOOL isRead = NO;
						if (categories != nil) {
							for (NSString *category in categories) {
								NSString *regexString = @"user/(.*?)/read$";
								NSString *matchedString = [category stringByMatching:regexString];
								if (matchedString != NULL) {
									isRead = YES;
									break;
								}
							}
						}
						
						NSDictionary *processedItem = [[NSDictionary alloc] initWithObjectsAndKeys:
													   itemId, @"itemId"
													   , published, @"published"
													   , updated, @"updated"
													   , title, @"title"
													   , content, @"content"
													   , summary, @"summary"
													   , feedTitle, @"feedTitle"
													   , URL, @"URL"
													   , streamId, @"streamId"
													   , itemFeedURL, @"itemFeedURL"
													   , [NSNumber numberWithBool:isRead], @"isRead"
													   , nil];
						[processedItems addObject:processedItem];
						[processedItem release];
					}
					
					dispatch_async(dispatch_get_main_queue(), ^{
						[self.delegate googleReaderReadingListData:processedItems];
						[processedItems release];
						
						if (isLastInSync) {
							self.gettingReadingList = NO;
							self.lastUpdate = [[NSDate date] timeIntervalSince1970];
							[self.delegate googleReaderReadingListDataComplete];
						}
					});
				});
			}
		}
	} else if (
			   [identifier isEqualToString:@"Mark as Read"]
			   || [identifier isEqualToString:@"Mark as Unread"]
			   || [identifier isEqualToString:@"Mark Feed as Read"]
			   ) {
		self.processingItemsToModify = NO;
		
		if (![[self.responseData objectForKey:identifier] isEqualToString:@"OK"] && [[self.itemsToModify objectAtIndex:0] objectForKey:@"retry"] == nil) {
			[[self.itemsToModify objectAtIndex:0] setObject:[NSNumber numberWithBool:YES] forKey:@"retry"];
			[self retrieveTokenWithSelectorName:@"processItemsToModify"];
			
			return;
		}
		
		if ([[self.responseData objectForKey:identifier] isEqualToString:@"OK"]) {
			[self.delegate googleReaderIsReadSynced:[[self.itemsToModify objectAtIndex:0] objectForKey:identifier]];
		}
		[self.itemsToModify removeObjectAtIndex:0];
		[self processItemsToModify];
	} else if ([identifier isEqualToString:@"Quick Add Feed"]) {
		NSDictionary *response = [self.json objectWithString:[self.responseData objectForKey:identifier]];
		if ([response objectForKey:@"streamId"] != nil && [response objectForKey:@"webfeedConfirmation"] == nil) {
			[self.delegate googleReaderSubscriptionAdded];
		} else {
			[self.delegate googleReaderCouldNotAddSubscription];
		}
		
	} else if ([identifier isEqualToString:@"Remove Feed"]) {
		NSString *response = [self.responseData objectForKey:identifier];
		
		if ([response isEqualToString:@"OK"]) {
			[self.delegate googleReaderSubscriptionRemoved];
		} else {
			[self.delegate googleReaderCouldNotRemoveSubscription];
		}
	}
	
	[self.connectionIdentifiers removeObjectForKey:[NSString stringWithFormat:@"%d", [connection hash]]];
	[connection release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	self.processingItemsToModify = NO;
	self.gettingReadingList = NO;
	[self.delegate googleReaderDecrementNetworkActivity];
	[self.delegate googleReaderURLError:error];
	[connection release];
}

@end

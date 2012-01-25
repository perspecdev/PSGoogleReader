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
#define kReadingListBatchSize @"50"

#import "PSGoogleReader.h"
#import "SBJson.h"
#import "RegexKitLite.h"
#import "GTMNSString+HTML.h"


@interface PSGoogleReader ()

@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) NSString *_username;
@property (nonatomic, strong) NSString *_password;
@property (nonatomic, strong) NSString *unixTimeCutoff;
@property (nonatomic) double readingListNewestRequestedItem;
@property (nonatomic, strong) NSString *excludeTarget;
@property (nonatomic, strong) NSString *numResults;
@property (nonatomic, strong) NSString *continuationString;
@property (nonatomic, strong) NSString *sortOrder;
@property (nonatomic, strong) NSString *itemIdentifier;
@property (nonatomic, strong) NSString *feedURL;
@property (nonatomic, strong) NSString *feedId;
@property (nonatomic, strong) SBJsonParser *json;
@property (atomic, strong) NSMutableSet *connections;
@property (nonatomic, strong) NSMutableDictionary *connectionIdentifiers;
@property (nonatomic, strong) NSMutableDictionary *responseData;
@property (nonatomic, strong) NSMutableArray *tokenSelectors;
@property (nonatomic, strong) NSMutableArray *itemsToModify;
@property (nonatomic) BOOL processingItemsToModify;
@property (nonatomic) BOOL needsLogin;
@property (nonatomic) BOOL gettingStarred;
@property (nonatomic) BOOL transitioningToGettingStarred;
@property (atomic, strong) NSMutableArray *itemBatches;
@property (nonatomic) int batchNumber;
@property (nonatomic) BOOL willGetMoreReadingListItemIds;
@property (nonatomic) BOOL hasMoreReadingListItemContents;
@property (nonatomic, copy) NSArray *lastRequestedItemIds;

- (NSString *)formattedItemIdsForRequest:(NSArray *)itemIds;
- (void)addBatchOfItems:(NSArray *)itemIds;
- (void)retrieveStarred;
- (void)retrieveReadingListContents;
- (void)finalizeReadingListBatchesWithFinalItems:(NSArray *)finalItems;

@end

@implementation PSGoogleReader

@synthesize SID;
@synthesize lastUpdate;
@synthesize gettingReadingList;
@synthesize delegate;

@synthesize token;
@synthesize _username;
@synthesize _password;
@synthesize unixTimeCutoff;
@synthesize readingListNewestRequestedItem;
@synthesize excludeTarget;
@synthesize numResults;
@synthesize continuationString;
@synthesize sortOrder;
@synthesize itemIdentifier;
@synthesize feedURL;
@synthesize feedId;
@synthesize json;
@synthesize connections;
@synthesize connectionIdentifiers;
@synthesize responseData;
@synthesize tokenSelectors;
@synthesize itemsToModify;
@synthesize processingItemsToModify;
@synthesize needsLogin;
@synthesize gettingStarred;
@synthesize transitioningToGettingStarred;
@synthesize itemBatches;
@synthesize batchNumber;
@synthesize willGetMoreReadingListItemIds;
@synthesize hasMoreReadingListItemContents;
@synthesize lastRequestedItemIds;

- (NSString *)username {
    return _username; 
}
- (NSString *)password {
    return _password; 
}

- (id)init {
	if ((self = [super init])) {
		[self setURLFormats];
		
        self.SID = @"";
        self.lastUpdate = 0;
        self.gettingReadingList = NO;
        self.gettingStarred = NO;
        self.transitioningToGettingStarred = NO;
        self.delegate = nil;
        
		self.token = @"no-token";
		self._username = @"";
		self._password = @"";
		self.unixTimeCutoff = @"";
        self.readingListNewestRequestedItem = 0;
		self.excludeTarget = @"";
		self.numResults = @"";
		self.continuationString = @"";
		self.sortOrder = @"";
		self.itemIdentifier = @"";
		self.feedURL = @"";
		self.feedId = @"";
        self.connections = [NSMutableSet setWithCapacity:1];
		self.connectionIdentifiers = [NSMutableDictionary dictionaryWithCapacity:1];
		self.responseData = [NSMutableDictionary dictionaryWithCapacity:1];
		self.tokenSelectors = [NSMutableArray arrayWithCapacity:0];
		self.itemsToModify = [NSMutableArray arrayWithCapacity:0];
		self.processingItemsToModify = NO;
        self.needsLogin = YES;
        self.itemBatches = [NSMutableArray arrayWithCapacity:0];
        self.batchNumber = 0;
        self.willGetMoreReadingListItemIds = NO;
        self.hasMoreReadingListItemContents = NO;
        self.lastRequestedItemIds = [NSArray array];
        
        self.json = [[SBJsonParser alloc] init];
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

- (void)resetForNewRequest {
    self.gettingReadingList = NO;
    self.gettingStarred = NO;
    self.transitioningToGettingStarred = NO;
    self.processingItemsToModify = NO;
    [self.itemsToModify removeAllObjects];
    [self.connectionIdentifiers removeAllObjects];
    [self.responseData removeAllObjects];
    [self.tokenSelectors removeAllObjects];
    [self.itemsToModify removeAllObjects];
    self.lastRequestedItemIds = [NSArray array];
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
	URLFormatGetReadingListIds = @"http://www.google.com/reader/api/0/stream/items/ids?s=user%2F-%2Fstate%2Fcom.google%2Freading-list&r=[sort-order]&xt=[exclude-target]&n=[num-results]&c=[continuation]&ot=0&nt=[newest-item]&merge=true&output=json&client=[client]";
    URLFormatGetStarredIds = @"http://www.google.com/reader/api/0/stream/items/ids?s=user%2F-%2Fstate%2Fcom.google%2Fstarred&r=[sort-order]&xt=[exclude-target]&n=[num-results]&c=[continuation]&ot=0&nt=[newest-item]&merge=true&output=json&client=[client]";
    URLFormatGetReadingListContents = @"http://www.google.com/reader/api/0/stream/items/contents?output=json&client=[client]";
	URLFormatGetSubscriptionList = @"http://www.google.com/reader/api/0/subscription/list?output=json&client=[client]&ck=[unix-time]";
	//URLFormatGetStarred = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/starred?n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatGetBroadcasted = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/broadcast?n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatGetNotes = @"http://www.google.com/reader/api/0/stream/contents/user/-/state/com.google/created?n=[num-results]&ck=[unix-time]&client=[client]";
	//URLFormatAddTag = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	//URLFormatRemoveTag = @"http://www.google.com/reader/api/0/edit-tag?client=[your client]";
	URLFormatSetRead = @"http://www.google.com/reader/api/0/edit-tag?client=[client]&ck=[unix-time]";
	URLFormatSetNotRead = @"http://www.google.com/reader/api/0/edit-tag?client=[client]&ck=[unix-time]";
	URLFormatSetFeedRead = @"http://www.google.com/reader/api/0/mark-all-as-read?client=[client]&ck=[unix-time]";
	URLFormatSetStarred = @"http://www.google.com/reader/api/0/edit-tag?client=[client]&ck=[unix-time]";
	URLFormatSetNotStarred = @"http://www.google.com/reader/api/0/edit-tag?client=[client]&ck=[unix-time]";
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
									  @"[item-identifier]", @"i"
                                      , @"user/-/state/com.google/starred", @"a"
                                      , @"edit", @"ac"
                                      , @"[token]", @"T"
                                      , nil];
	NSDictionary *setNotStarredFields = [NSDictionary dictionaryWithObjectsAndKeys:
										 @"[item-identifier]", @"i"
                                         , @"user/-/state/com.google/starred", @"r"
                                         , @"edit", @"ac"
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
                   , nil] copy];
}

- (NSString *)populateURLFormatFields:(NSString *)URLFormat {
	NSString *URL = [URLFormat copy];
	URL = [URL stringByReplacingOccurrencesOfString:@"[email]" withString:self._username];
	URL = [URL stringByReplacingOccurrencesOfString:@"[password]" withString:self._password];
	URL = [URL stringByReplacingOccurrencesOfString:@"[unix-time-cutoff]" withString:self.unixTimeCutoff];
	URL = [URL stringByReplacingOccurrencesOfString:@"[sort-order]" withString:self.sortOrder];
	URL = [URL stringByReplacingOccurrencesOfString:@"[exclude-target]" withString:self.excludeTarget];
	URL = [URL stringByReplacingOccurrencesOfString:@"[unix-time]" withString:[NSString stringWithFormat:@"%d", (long)[[NSDate date] timeIntervalSince1970]]];
	URL = [URL stringByReplacingOccurrencesOfString:@"[unix-time-microseconds]" withString:[NSString stringWithFormat:@"%d000000", (long)[[NSDate date] timeIntervalSince1970]]];
    URL = [URL stringByReplacingOccurrencesOfString:@"[newest-item]" withString:[NSString stringWithFormat:@"%0.0f", self.readingListNewestRequestedItem]];
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

- (NSString *)formattedItemIdsForRequest:(NSArray *)itemIds {
    NSMutableString *string = [NSMutableString string];
    for (NSString *itemId in itemIds) {
        [string appendString:[NSString stringWithFormat:@"&i=%@", itemId]];
    }
    
    return string;
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
        self.gettingReadingList = NO;
		[self.delegate googleReaderNeedsLogin];
		return;
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
    [request setTimeoutInterval:10];
	
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
	[self.connections addObject:connection];
    
    //NSLog(@"%@, %@", URL, [postData description]);
	[self.responseData setObject:@"" forKey:identifier];
	[self.connectionIdentifiers setObject:identifier forKey:[NSString stringWithFormat:@"%d", [connection hash]]];
	
	[self.delegate googleReaderIncrementNetworkActivity];
}

- (void)loginWithUsername:(NSString *)aUsername withPassword:(NSString *)aPassword {
    NSString *theUsername = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge_retained CFStringRef)aUsername, NULL, CFSTR("￼=,!$&'()*+;@?\n\"<>#\t :/"), kCFStringEncodingUTF8);
	NSString *thePassword = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge_retained CFStringRef)aPassword, NULL, CFSTR("￼=,!$&'()*+;@?\n\"<>#\t :/"), kCFStringEncodingUTF8);
	self._username = theUsername;
    self._password = thePassword;
    
	NSString *URL = [self populateURLFormatFields:URLFormatGetSID];
	
	NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"getSID"]];
	
	[self startConnectionWithURL:URL withIdentifier:@"SID" sendCookie:NO withPostData:postData];
}

- (void)logout {
	self.SID = @"";
	self.needsLogin = YES;
    self.gettingReadingList = NO;
	/*[queue cancelAllOperations];*/
	[self.delegate googleReaderNeedsLogin];
}

- (void)retrieveTokenWithSelectorName:(NSString *)selectorName {
    if (![self.token isEqualToString:@"retrieving-token"]) {
        self.token = @"retrieving-token";
        NSString *URL = [self populateURLFormatFields:URLFormatGetToken];
        
        [self.tokenSelectors addObject:selectorName];
        [self startConnectionWithURL:URL withIdentifier:@"Token" sendCookie:YES withPostData:nil];
    }
}

- (void)addBatchOfItems:(NSArray *)itemIds {
    BOOL needToStartRequestingContents = NO;
    if (self.batchNumber == 0 || (self.transitioningToGettingStarred && [self.itemBatches count] == 0)) {
        self.transitioningToGettingStarred = NO;
        
        self.hasMoreReadingListItemContents = YES;
        needToStartRequestingContents = YES;
    }
    
    [self.itemBatches addObject:itemIds];
    
    if (needToStartRequestingContents) {
        [self retrieveReadingListContents];
    }
}

- (void)retrieveReadingList {
    if (!self.gettingReadingList) {
        self.readingListNewestRequestedItem = [[NSDate date] timeIntervalSince1970];
        self.batchNumber = 0;
        [self.itemBatches removeAllObjects];
    }
	self.gettingReadingList = YES;
	
    self.unixTimeCutoff = [NSString stringWithFormat:@"%d", (long)[[NSDate date] timeIntervalSince1970]];
	self.sortOrder = @"d"; // descending order
	self.excludeTarget = @"user/-/state/com.google/read"; // items marked as read
    self.numResults = kReadingListBatchSize;
	
	NSString *URL = [self populateURLFormatFields:URLFormatGetReadingListIds];
	
	[self startConnectionWithURL:URL withIdentifier:@"Reading List IDs" sendCookie:YES withPostData:nil];
}

- (void)retrieveStarred {
    if (!self.gettingStarred) {
        self.readingListNewestRequestedItem = [[NSDate date] timeIntervalSince1970];
    }
	self.gettingStarred = YES;
	
    self.unixTimeCutoff = [NSString stringWithFormat:@"%d", (long)[[NSDate date] timeIntervalSince1970]];
	self.sortOrder = @"d"; // descending order
	self.excludeTarget = @"user/-/state/com.google/unread"; // items marked as unread (because we already got them in the reading list)
    self.numResults = kReadingListBatchSize;
	
	NSString *URL = [self populateURLFormatFields:URLFormatGetStarredIds];
	
	[self startConnectionWithURL:URL withIdentifier:@"Reading List IDs" sendCookie:YES withPostData:nil];
}

- (void)retrieveReadingListContents {
    self.batchNumber++;
    
    NSString *URL = [self populateURLFormatFields:URLFormatGetReadingListContents];
	
    NSArray *itemIds = [self.itemBatches objectAtIndex:0];
    [self.itemBatches removeObjectAtIndex:0];
    NSString *postData = [self formattedItemIdsForRequest:itemIds];
    
	[self startConnectionWithURL:URL withIdentifier:[NSString stringWithFormat:@"Reading List Contents %d", self.batchNumber] sendCookie:YES withPostData:postData];
}

- (void)finalizeReadingListBatchesWithFinalItems:(NSArray *)finalItems {
    self.lastUpdate = [[NSDate date] timeIntervalSince1970];
    [self.delegate googleReaderReadingListDataWillComplete];
    
    if (finalItems == nil) {
        finalItems = [NSArray array];
    }
    [self.delegate googleReaderReadingListData:finalItems isLastBatch:YES];
    
    [self.delegate googleReaderReadingListDataDidComplete];
    
    [self resetForNewRequest];
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

- (void)markAsStarred:(NSString *)itemId {
    [self.itemsToModify addObject:[NSMutableDictionary dictionaryWithObject:itemId forKey:@"Mark as Starred"]];
	[self processItemsToModify];
}

- (void)markAsUnstarred:(NSString *)itemId {
    [self.itemsToModify addObject:[NSMutableDictionary dictionaryWithObject:itemId forKey:@"Mark as Unstarred"]];
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
			actionToPerform = [key copy];
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
		} else if ([actionToPerform isEqualToString:@"Mark as Starred"]) {
			NSString *URL = [self populateURLFormatFields:URLFormatSetStarred];
            self.itemIdentifier = itemId;
			NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"setStarred"]];
			[self startConnectionWithURL:URL withIdentifier:@"Mark as Starred" sendCookie:YES withPostData:postData];
		} else if ([actionToPerform isEqualToString:@"Mark as Unstarred"]) {
			NSString *URL = [self populateURLFormatFields:URLFormatSetNotStarred];
            self.itemIdentifier = itemId;
			NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"setNotStarred"]];
			[self startConnectionWithURL:URL withIdentifier:@"Mark as Unstarred" sendCookie:YES withPostData:postData];
		} else if ([actionToPerform isEqualToString:@"Mark Feed as Read"]) {
			NSString *URL = [self populateURLFormatFields:URLFormatSetFeedRead];
            self.itemIdentifier = @"";
			self.feedId = itemId;
			NSString *postData = [self getFormattedQueryStringFromDictionary:[postFields objectForKey:@"setFeedRead"]];
			[self startConnectionWithURL:URL withIdentifier:@"Mark Feed as Read" sendCookie:YES withPostData:postData];
		} else {
			self.processingItemsToModify = NO;
		}
	} else {
		self.processingItemsToModify = NO;
	}
    
}

- (void)rerunActionForConnectionIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"SID"]) {
        [self logout];
    } else if ([identifier isEqualToString:@"Token"]) {
        [self logout];
    } else if ([identifier isEqualToString:@"Token Try Again"]) {
        [self logout];
    } else if ([identifier isEqualToString:@"Subscription List"]) {
        [self retrieveSubscriptionList];
    } else if ([identifier isEqualToString:@"Unread Count"]) {
        [self retrieveUnreadCount];
    } else if ([identifier isEqualToString:@"Reading List IDs"]) {
        [self retrieveReadingList];
    } else if ([identifier hasPrefix:@"Reading List Contents"]) {
        [self cancelAllConnections];
        [self resetForNewRequest];
        [self retrieveReadingList];
    } else if ([identifier isEqualToString:@"Mark as Read"]) {
        [self processItemsToModify];
    } else if ([identifier isEqualToString:@"Mark as Unread"]) {
        [self processItemsToModify];
    } else if ([identifier isEqualToString:@"Mark as Starred"]) {
        [self processItemsToModify];
    } else if ([identifier isEqualToString:@"Mark as Unstarred"]) {
        [self processItemsToModify];
    } else if ([identifier isEqualToString:@"Mark Feed as Read"]) {
        [self processItemsToModify];
    } else if ([identifier isEqualToString:@"Quick Add Feed"]) {
        [self quickAddFeedFromPresetURL];
    } else if ([identifier isEqualToString:@"Remove Feed"]) {
        [self removeFeedFromPresetId];
    }
}

- (void)cancelAllConnections {
    for (NSURLConnection *connection in self.connections) {
        [connection cancel];
        [self.delegate googleReaderDecrementNetworkActivity];
    }
}


#pragma mark -
#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // TODO: I think invalid SID (meaning we need to log back in) should actually only be 401.
    // But there were some problems with just checking for 401 where we needed to log back in
    // but the statusCode wasn't 401.  So just going the aggressive/safe route here...
	if ([(NSHTTPURLResponse *)response statusCode] < 200 || [(NSHTTPURLResponse *)response statusCode] >= 300) {
        NSString *badTokenResponse = [[(NSHTTPURLResponse *)response allHeaderFields] valueForKey:@"X-Reader-Google-Bad-Token"];
        if (badTokenResponse != nil && [badTokenResponse isEqualToString:@"true"]) {
            self.token = @"no-token";
            NSString *identifier = [self.connectionIdentifiers objectForKey:[NSString stringWithFormat:@"%d", [connection hash]]];
            [self rerunActionForConnectionIdentifier:identifier];
        } else {
            [self.connections removeObject:connection];
            [connection cancel];
            [self.delegate googleReaderDecrementNetworkActivity];
            self.needsLogin = YES;
            self.gettingReadingList = NO;
            [self.delegate googleReaderNeedsLogin];
        }
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSString *identifier = [self.connectionIdentifiers objectForKey:[NSString stringWithFormat:@"%d", [connection hash]]];
	
	NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (dataString == nil) {
		return;
	}
	
	if (
		[identifier isEqualToString:@"SID"]
		|| [identifier isEqualToString:@"Token"]
		|| [identifier isEqualToString:@"Token Try Again"]
		|| [identifier isEqualToString:@"Subscription List"]
		|| [identifier isEqualToString:@"Unread Count"]
		|| [identifier isEqualToString:@"Reading List IDs"]
		|| [identifier hasPrefix:@"Reading List Contents"]
		|| [identifier isEqualToString:@"Mark as Read"]
		|| [identifier isEqualToString:@"Mark as Unread"]
		|| [identifier isEqualToString:@"Mark as Starred"]
		|| [identifier isEqualToString:@"Mark as Unstarred"]
		|| [identifier isEqualToString:@"Mark Feed as Read"]
		|| [identifier isEqualToString:@"Quick Add Feed"]
		|| [identifier isEqualToString:@"Remove Feed"]
		) {
		[self.responseData setObject:[[self.responseData objectForKey:identifier] stringByAppendingString:dataString] forKey:identifier];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self.delegate googleReaderDecrementNetworkActivity];
	
	NSString *identifier = [self.connectionIdentifiers objectForKey:[NSString stringWithFormat:@"%d", [connection hash]]];
    
    //NSLog(@"connectionDidFinishLoading: %@", identifier);
	
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
            self.gettingReadingList = NO;
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                // we can safely ignore the warning here because the methods the selectors point to aren't returning any objects that they allocated
				[self performSelector:NSSelectorFromString(selectorName)];
#pragma clang diagnostic pop
			}
		} else {
            self.token = @"";
		}
        
	} else if ([identifier isEqualToString:@"Subscription List"]) {
		NSArray *subscriptionList = [[self.json objectWithString:[[self.responseData objectForKey:identifier] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]] objectForKey:@"subscriptions"];
		[self.delegate googleReaderSubscriptionList:subscriptionList];
	} else if ([identifier isEqualToString:@"Unread Count"]) {
		//
	} else if ([identifier isEqualToString:@"Reading List IDs"]) {
        if (!self.needsLogin) {
            NSDictionary *responseObject = [self.json objectWithString:[self.responseData objectForKey:identifier]];
            NSArray *itemIds = [responseObject objectForKey:@"itemRefs"];
            //NSLog(@"%@, %d, %d", identifier, [itemIds count], self.gettingStarred);
            if (itemIds == nil) {
                [self cancelAllConnections];
                [self resetForNewRequest];
                [self.delegate googleReaderCouldNotGetReadingList];
            } else {
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSMutableArray *requestedItemIds = [NSMutableArray arrayWithCapacity:[itemIds count]];
                    double oldestTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000000;
                    for (NSDictionary *item in itemIds) {
                        [requestedItemIds addObject:[item valueForKey:@"id"]];
                        double timestamp = [[item valueForKey:@"timestampUsec"] doubleValue];
                        if (timestamp < oldestTimeStamp) oldestTimeStamp = timestamp;
                    }
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        self.readingListNewestRequestedItem = floor(oldestTimeStamp / 1000000);
                        
                        BOOL needToGetStarredItems = NO;
                        
                        // if itemIds contains 0 objects then obviously there are no more to get.
                        // if the batch of requested items is the same as the last batch, then there are also no more to get
                        // since we could be requesting the same items over and over again, based on the seconds (converted from microseconds)
                        // of self.readingListNewestRequestedItem (see above)
                        if ([itemIds count] > 0 && ![requestedItemIds isEqualToArray:self.lastRequestedItemIds]) {
                            self.willGetMoreReadingListItemIds = YES;
                            [self addBatchOfItems:requestedItemIds];
                            self.lastRequestedItemIds = requestedItemIds;
                        } else {
                            if (self.gettingStarred) {
                                self.willGetMoreReadingListItemIds = NO;
                            } else {
                                needToGetStarredItems = YES;
                                self.transitioningToGettingStarred = YES;
                                self.willGetMoreReadingListItemIds = YES;
                            }
                        }
                        
                        if (!self.willGetMoreReadingListItemIds) {
                            if (!self.hasMoreReadingListItemContents) {
                                // need this here because it's possible that, because this connection can return 0 itemIds,
                                // this connection may return after the final reading list contents connection is processed
                                [self finalizeReadingListBatchesWithFinalItems:nil];
                            }
                        } else {
                            if (self.gettingStarred || needToGetStarredItems) {
                                [self retrieveStarred];
                            } else {
                                [self retrieveReadingList];
                            }
                        }
                    });
                });
            }
        }
    } else if ([identifier hasPrefix:@"Reading List Contents"]) {
        if (!self.needsLogin) {
            NSError *error = nil;
			NSDictionary *responseObject = [self.json objectWithString:[self.responseData objectForKey:identifier] error:&error];
			NSArray *readingList = [responseObject objectForKey:@"items"];
            //NSLog(@"%@, %d", identifier, [readingList count]);
			if (readingList == nil) {
				//NSLog(@"%@", [error description]);
				[self cancelAllConnections];
                [self resetForNewRequest];
				[self.delegate googleReaderCouldNotGetReadingList];
			} else {
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
                        if (summary == NULL || summary == nil) summary = @"";
                        if (content == NULL || content == nil || [content isEqualToString:@""]) content = [NSString stringWithFormat:@"%@", summary];
                        
                        NSString *feedTitle = [[item objectForKey:@"origin"] objectForKey:@"title"];
                        if (feedTitle == nil) continue;
                        
                        title = [title gtm_stringByUnescapingFromHTML];
                        summary = [summary gtm_stringByUnescapingFromHTML];
                        content = [content gtm_stringByUnescapingFromHTML];
                        feedTitle = [feedTitle gtm_stringByUnescapingFromHTML];
                        
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
                        BOOL isStarred = NO;
                        if (categories != nil) {
                            for (NSString *category in categories) {
                                NSString *isReadRegex = @"user/(.*?)/read$";
                                NSString *isStarredRegex = @"user/(.*?)/starred$";
                                NSString *matchedIsReadString = [category stringByMatching:isReadRegex];
                                NSString *matchedIsStarredString = [category stringByMatching:isStarredRegex];
                                if (matchedIsReadString != NULL) {
                                    isRead = YES;
                                }
                                if (matchedIsStarredString != NULL) {
                                    isStarred = YES;
                                    //NSLog(@"starred: %@", title);
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
                                                       , [NSNumber numberWithBool:isStarred], @"isStarred"
                                                       , nil];
                        [processedItems addObject:processedItem];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.hasMoreReadingListItemContents = ([self.itemBatches count] > 0);
                        
                        if (!self.hasMoreReadingListItemContents) {
                            if (!self.willGetMoreReadingListItemIds) {
                                [self finalizeReadingListBatchesWithFinalItems:processedItems];
                            } else {
                                [self.delegate googleReaderReadingListData:processedItems isLastBatch:NO];
                            }
                        } else {
                            [self.delegate googleReaderReadingListData:processedItems isLastBatch:NO];
                            [self retrieveReadingListContents];
                        }
                    });
                });
			}
		}
	} else if (
			   [identifier isEqualToString:@"Mark as Read"]
			   || [identifier isEqualToString:@"Mark as Unread"]
			   || [identifier isEqualToString:@"Mark Feed as Read"]
			   || [identifier isEqualToString:@"Mark as Starred"]
			   || [identifier isEqualToString:@"Mark as Unstarred"]
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
    [self.connections removeObject:connection];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.connections removeObject:connection];
	self.processingItemsToModify = NO;
	self.gettingReadingList = NO;
	[self.delegate googleReaderDecrementNetworkActivity];
	[self.delegate googleReaderURLError:error];
}

@end

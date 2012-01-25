//
//  PSGoogleReader.h
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

#import <Foundation/Foundation.h>

@class SBJsonParser;

@protocol PSGoogleReaderDelegate

- (void)googleReaderIncrementNetworkActivity;
- (void)googleReaderDecrementNetworkActivity;
- (void)googleReaderInitializedAndReady;
- (void)googleReaderNeedsLogin;
- (void)googleReaderReadingListData:(NSArray *)items isLastBatch:(BOOL)isLastBatch;
- (BOOL)googleReaderIsReadyForMoreItems;
- (void)googleReaderReadingListDataWillComplete;
- (void)googleReaderReadingListDataDidComplete;
- (void)googleReaderCouldNotGetReadingList;
- (void)googleReaderSubscriptionList:(NSArray *)aSubscriptionList;
- (void)googleReaderIsReadSynced:(NSString *)itemId;
- (void)googleReaderSubscriptionAdded;
- (void)googleReaderCouldNotAddSubscription;
- (void)googleReaderSubscriptionRemoved;
- (void)googleReaderCouldNotRemoveSubscription;
- (void)googleReaderURLError:(NSError *)error;

@end

@interface PSGoogleReader : NSObject <NSURLConnectionDataDelegate> {
    NSString *SID;
    NSTimeInterval lastUpdate;
    BOOL gettingReadingList;
    id __weak delegate;
    
    NSString *URLFormatGetSID;
	NSString *URLFormatGetToken;
	NSString *URLFormatQuickAddFeed;
	NSString *URLFormatAddFeed;
	NSString *URLFormatEditFeed;
	NSString *URLFormatRemoveFeed;
	NSString *URLFormatSetFeedLabel;
	NSString *URLFormatGetUnreadCount;
	NSString *URLFormatGetUserInfo;
	NSString *URLFormatGetFeed;
	NSString *URLFormatGetLabel;
	NSString *URLFormatGetReadingListIds;
    NSString *URLFormatGetStarredIds;
    NSString *URLFormatGetReadingListContents;
	NSString *URLFormatGetSubscriptionList;
	NSString *URLFormatGetStarred;
	NSString *URLFormatGetBroadcasted;
	NSString *URLFormatGetNotes;
	NSString *URLFormatAddTag;
	NSString *URLFormatRemoveTag;
	NSString *URLFormatSetRead;
	NSString *URLFormatSetNotRead;
	NSString *URLFormatSetFeedRead;
	NSString *URLFormatSetStarred;
	NSString *URLFormatSetNotStarred;
	NSString *URLFormatSetLike;
	NSString *URLFormatSetNotLike;
	NSString *URLFormatSetBroadcast;
	NSString *URLFormatSetNotBroadcast;
	NSString *URLFormatEmail;
	
	NSMutableDictionary *postFields;
	
	NSString *username;
	NSString *password;
	NSString *token;
	NSString *unixTimeCutoff;
	NSString *excludeTarget;
	NSString *numResults;
	NSString *continuationString;
	NSString *client;
	NSString *sortOrder;
	NSString *itemIdentifier;
	NSString *feedURL;
	NSString *feedId;
    BOOL needsLogin;
	BOOL processingItemsToModify;
	
	NSMutableDictionary *cookieInfo;
    NSMutableSet *connections;
	NSMutableDictionary *connectionIdentifiers;
	NSMutableDictionary *responseData;
	NSMutableArray *tokenSelectors;
	NSMutableArray *itemsToModify;
	SBJsonParser *json;
}

@property (nonatomic, weak) id<PSGoogleReaderDelegate> delegate;
@property (nonatomic, strong) NSString *SID;
@property (nonatomic, readonly) NSString *username;
@property (nonatomic, readonly) NSString *password;
@property (nonatomic) NSTimeInterval lastUpdate;
@property (nonatomic) BOOL gettingReadingList;

- (id)init;
- (id)initWithSID:(NSString *)anSID;
- (void)resetForNewRequest;
- (void)setURLFormats;
- (void)loginWithUsername:(NSString *)aUsername withPassword:(NSString *)aPassword;
- (void)logout;
- (void)retrieveTokenWithSelectorName:(NSString *)selectorName;
- (void)retrieveSubscriptionList;
- (void)retrieveUnreadCount;
- (void)retrieveReadingList;
- (void)markAsRead:(NSString *)itemId;
- (void)markAsUnread:(NSString *)itemId;
- (void)markAsStarred:(NSString *)itemId;
- (void)markAsUnstarred:(NSString *)itemId;
- (void)markFeedAsRead:(NSString *)aFeedId;
- (void)quickAddFeed:(NSString *)aFeedURL;
- (void)quickAddFeedFromPresetURL;
- (void)removeFeed:(NSString *)aFeedId;
- (void)removeFeedFromPresetId;
- (void)processItemsToModify;
- (void)rerunActionForConnectionIdentifier:(NSString *)identifier;
- (void)cancelAllConnections;

@end
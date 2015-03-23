//
//  TwitterPlugin.h
//  TwitterPlugin
//
//  Created by Antonelli Brian on 10/13/11.
//  Modify by Jesus Torres on 03/23/14.

    #import <Foundation/Foundation.h>
    #import <Social/Social.h>
    #import <Accounts/Accounts.h>
    #import <Cordova/CDVPlugin.h>
    #import <Cordova/CDVJSON.h>


@interface TwitterPlugin : CDVPlugin{
}


- (void) isTwitterAvailable:(CDVInvokedUrlCommand*)command;

- (void) isTwitterSetup:(CDVInvokedUrlCommand*)command;

- (void) composeTweet:(CDVInvokedUrlCommand*)command;

- (void) sendTweet:(CDVInvokedUrlCommand*)command;

- (void) getPublicTimeline:(CDVInvokedUrlCommand*)command;

- (void) searchByHashtag:(CDVInvokedUrlCommand*)command;

- (void) getTwitterUsername:(CDVInvokedUrlCommand*)command;

- (void) getTwitterProfile:(CDVInvokedUrlCommand*)command;

- (void) getMentions:(CDVInvokedUrlCommand*)command;

- (void) getTWRequest:(CDVInvokedUrlCommand*)command;

- (void) reTweet:(CDVInvokedUrlCommand*)command;

- (void) addFavorites:(CDVInvokedUrlCommand*)command;

- (void) rmFavorites:(CDVInvokedUrlCommand*)command;

- (void) performCallbackOnMainThreadforJS:(NSString*)js;

@end

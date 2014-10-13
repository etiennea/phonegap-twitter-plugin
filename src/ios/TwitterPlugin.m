//
//  TwitterPlugin.m
//  TwitterPlugin
//
//  Created by Antonelli Brian on 10/13/11.
//

    #import "TwitterPlugin.h"
    #import <Cordova/CDVJSON.h>
    #import <Cordova/CDVAvailability.h>

#define TWITTER_URL @"http://api.twitter.com/1.1/"

@implementation TwitterPlugin

- (void) isTwitterAvailable:(CDVInvokedUrlCommand*)command {
    TWTweetComposeViewController *tweetViewController = [[TWTweetComposeViewController alloc] init];
    BOOL twitterSDKAvailable = tweetViewController != nil;

    [super writeJavascript:[[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:twitterSDKAvailable ? 1 : 0] toSuccessCallbackString:command.callbackId]];
}

- (void) isTwitterSetup:(CDVInvokedUrlCommand*)command {
    BOOL canTweet = [TWTweetComposeViewController canSendTweet];

    [super writeJavascript:[[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:canTweet ? 1 : 0] toSuccessCallbackString:command.callbackId]];
}

- (void) composeTweet:(CDVInvokedUrlCommand*)command {
    // arguments: callback, tweet text, url attachment, image attachment
    NSMutableDictionary* options = (NSMutableDictionary*)[command argumentAtIndex:0];
    NSString *callbackId = command.callbackId;
    NSString *tweetText = [options objectForKey:@"text"];
    NSString *urlAttach = [options objectForKey:@"urlAttach"];
    NSString *imageAttach = [options objectForKey:@"imageAttach"];
    
    TWTweetComposeViewController *tweetViewController = [[TWTweetComposeViewController alloc] init];
    
    BOOL ok = YES;
    NSString *errorMessage;
    
    if(tweetText != nil){
        ok = [tweetViewController setInitialText:tweetText];
        if(!ok){
            errorMessage = @"Tweet is too long";
        }
    }
    

    
    if(imageAttach != nil){
        // Note that the image is loaded syncronously
        if([imageAttach hasPrefix:@"http://"]){
            UIImage *img = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imageAttach]]];
            ok = [tweetViewController addImage:img];
        }
        else{
            ok = [tweetViewController addImage:[UIImage imageNamed:imageAttach]];
        }
        if(!ok){
            errorMessage = @"Image could not be added";
        }
    }
    
    if(urlAttach != nil){
        ok = [tweetViewController addURL:[NSURL URLWithString:urlAttach]];
        if(!ok){
            errorMessage = @"URL too long";
        }
    }

    
    
    if(!ok){        
        [super writeJavascript:[[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                               messageAsString:errorMessage] toErrorCallbackString:callbackId]];
    }
    else{
        
#if TARGET_IPHONE_SIMULATOR
        NSString *simWarning = @"Test TwitterPlugin on Real Hardware. Tested on Cordova 2.0.0";
        //EXC_BAD_ACCESS occurs on simulator unable to reproduce on real device
        //running iOS 5.1 and Cordova 1.6.1
        NSLog(@"%@",simWarning);
#endif
        
        [tweetViewController setCompletionHandler:^(TWTweetComposeViewControllerResult result) {
            switch (result) {
                case TWTweetComposeViewControllerResultDone:
                    [super writeJavascript:[[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] toSuccessCallbackString:callbackId]];
                    break;
                case TWTweetComposeViewControllerResultCancelled:
                default:
                    [super writeJavascript:[[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                           messageAsString:@"Cancelled"] toErrorCallbackString:callbackId]];
                    break;
            }
            
            [super.viewController dismissModalViewControllerAnimated:YES];
            
        }];
        
        [super.viewController presentModalViewController:tweetViewController animated:YES];
    }
}

- (void) getPublicTimeline:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    NSString *url = [NSString stringWithFormat:@"%@statuses/public_timeline.json", TWITTER_URL];
    
    TWRequest *postRequest = [[TWRequest alloc] initWithURL:[NSURL URLWithString:url] parameters:nil requestMethod:TWRequestMethodGET];
    [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSString *jsResponse;
        
        if([urlResponse statusCode] == 200) {
            NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSDictionary *dict = [dataString JSONObject];
            jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict] toSuccessCallbackString:callbackId];
        }
        else{
            jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                        messageAsString:[NSString stringWithFormat:@"HTTP Error: %i", [urlResponse statusCode]]] 
                                  toErrorCallbackString:callbackId];
        }
        
        [self performCallbackOnMainThreadforJS:jsResponse];        
    }];
}

- (void) getTwitterUsername:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
            NSString *username = twitterAccount.username;
            
            NSString *jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_OK 
                                                      messageAsString:username] 
                                    toSuccessCallbackString:callbackId];
            [self performCallbackOnMainThreadforJS:jsResponse];
        }
    }];

}

- (void) getTwitterProfile:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    NSString *url = [NSString stringWithFormat:@"%@users/show.json", TWITTER_URL];
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            if ([accountsArray count]>0){
                ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
                NSString *username = twitterAccount.username;
                
                NSMutableDictionary *md = [NSMutableDictionary dictionary];
                md[@"screen_name"] = username;
                
                TWRequest *postRequest = [[TWRequest alloc] initWithURL:[NSURL URLWithString:url] parameters:md requestMethod:TWRequestMethodGET];
                [postRequest setAccount:[accountsArray objectAtIndex:0]];
                [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    NSString *jsResponse;
                    NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                    
                    if([urlResponse statusCode] == 200) {
                        NSDictionary *dict = [dataString JSONObject];
                        jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict] toSuccessCallbackString:callbackId];
                    }else{
                        if (![username isEqualToString:@""]){
                            jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                            messageAsString:username]
                                          toSuccessCallbackString:callbackId];
                        }else{
                            jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                            messageAsString:[NSString stringWithFormat:@"HTTP Error: %li", (long)[urlResponse statusCode]]]
                                          toErrorCallbackString:callbackId];
                        }
                    }
                    
                    [self performCallbackOnMainThreadforJS:jsResponse];
                }];
            }else{
                [self performCallbackOnMainThreadforJS:[[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                          messageAsString:@"No twitter account set up.Add a new account going to Settings -> Twitter"]
                                                        toErrorCallbackString:callbackId]];
            }
        }else{
            [self performCallbackOnMainThreadforJS:[[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                      messageAsString:[NSString stringWithFormat:@"Please allow %@ to access your twitter account. Go to Settings -> Twitter -> Enable %@.",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]]]
                                                    toErrorCallbackString:callbackId]];
        }
    }];
}

- (void) getMentions:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    NSString *url = [NSString stringWithFormat:@"%@statuses/mentions.json", TWITTER_URL];
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            // making assumption they only have one twitter account configured, should probably revist
            if([accountsArray count] > 0) {
                TWRequest *postRequest = [[TWRequest alloc] initWithURL:[NSURL URLWithString:url] parameters:nil requestMethod:TWRequestMethodGET];
                [postRequest setAccount:[accountsArray objectAtIndex:0]];
                [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    NSString *jsResponse;
                    if([urlResponse statusCode] == 200) {
                        NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                        NSDictionary *dict = [dataString JSONObject];
                        jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict] toSuccessCallbackString:callbackId];
                    }
                    else{
                        jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                     messageAsString:[NSString stringWithFormat:@"HTTP Error: %i", [urlResponse statusCode]]] 
                                      toErrorCallbackString:callbackId];
                    }
                    
                    [self performCallbackOnMainThreadforJS:jsResponse];        
                }];
            }
            else{
                NSString *jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                             messageAsString:@"No Twitter accounts available"] 
                              toErrorCallbackString:callbackId];
                [self performCallbackOnMainThreadforJS:jsResponse];
            }
        }
        else{
            NSString *jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                         messageAsString:@"Access to Twitter accounts denied by user"] 
                          toErrorCallbackString:callbackId];
            [self performCallbackOnMainThreadforJS:jsResponse];
        }
    }];
}



- (void) getTWRequest:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    NSMutableDictionary* options = (NSMutableDictionary*)[command argumentAtIndex:0];
    NSString *urlSlug = [options objectForKey:@"url"];
    NSString *url = [NSString stringWithFormat:@"%@%@", TWITTER_URL, urlSlug];
    
    NSDictionary *params = [options objectForKey:@"params"] ?: nil;
    // We might want to safety check here that params is indeed a dictionary.
    
    NSString *reqMethod = [options objectForKey:@"requestMethod"] ?: @"";
    TWRequestMethod method;
    if ([reqMethod isEqualToString:@"POST"]) {
        method = TWRequestMethodPOST;
        NSLog(@"POST");
    }
    else if ([reqMethod isEqualToString:@"DELETE"]) {
        method = TWRequestMethodDELETE;
        NSLog(@"DELETE");
    }
    else {
        method = TWRequestMethodGET;
        NSLog(@"GET");
    }
    
    
    // We should probably store the chosen account as an instance variable so as to not request it for every request.
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType withCompletionHandler:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            // making assumption they only have one twitter account configured, should probably revist
            if([accountsArray count] > 0) {
                TWRequest *request = [[TWRequest alloc] initWithURL:[NSURL URLWithString:url] 
                                                            parameters:params
                                                            requestMethod:method];
                
                [request setAccount:[accountsArray objectAtIndex:0]];
                [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    NSString *jsResponse;
                    if([urlResponse statusCode] == 200) {
                        NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                        NSDictionary *dict = [dataString JSONObject];
                        jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict] toSuccessCallbackString:callbackId];
                    }
                    else{
                        jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                        messageAsString:[NSString stringWithFormat:@"HTTP Error: %i", [urlResponse statusCode]]] 
                                      toErrorCallbackString:callbackId];
                    }
                    
                    [self performCallbackOnMainThreadforJS:jsResponse];        
                }];
            }
            else{
                NSString *jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                          messageAsString:@"No Twitter accounts available"] 
                                        toErrorCallbackString:callbackId];
                [self performCallbackOnMainThreadforJS:jsResponse];
            }
        }
        else{
            NSString *jsResponse = [[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR 
                                                      messageAsString:@"Access to Twitter accounts denied by user"] 
                                    toErrorCallbackString:callbackId];
            [self performCallbackOnMainThreadforJS:jsResponse];
        }
    }];
}





// The JS must run on the main thread because you can't make a uikit call (uiwebview) from another thread (what twitter does for calls)
- (void) performCallbackOnMainThreadforJS:(NSString*)javascript{
    [super performSelectorOnMainThread:@selector(writeJavascript:) 
                            withObject:javascript
                         waitUntilDone:YES];
}

@end
//
//  TwitterPlugin.m
//  TwitterPlugin
//
//  Created by Antonelli Brian on 10/13/11.
//  Modify by Jesus Torres on 03/23/14.

#import "TwitterPlugin.h"
#import <Cordova/CDVJSON.h>
#import <Cordova/CDVAvailability.h>
#import <Social/Social.h>

#define TWITTER_URL @"https://api.twitter.com/1.1/"

@implementation TwitterPlugin

- (void) isTwitterAvailable:(CDVInvokedUrlCommand*)command
{

    CDVPluginResult* pluginResult = nil;

    if([SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]){
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:TRUE];
    }else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:FALSE];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) isTwitterSetup:(CDVInvokedUrlCommand*)command
{
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
        CDVPluginResult* pluginResult = nil;
        if (granted == YES)
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:TRUE];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No user granted"];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     }];
}

- (void) composeTweet:(CDVInvokedUrlCommand*)command
{
    // arguments: callback, tweet text, url attachment, image attachment
    CDVPluginResult* pluginResult = nil;
    NSMutableDictionary* options = (NSMutableDictionary*)[command argumentAtIndex:0];
    NSString *tweetText = [options objectForKey:@"text"];
    NSString *urlAttach = [options objectForKey:@"urlAttach"];
    NSString *imageAttach = [options objectForKey:@"imageAttach"];

    SLComposeViewController *composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];

    BOOL ok = YES;
    NSString *errorMessage;

    if(tweetText != nil)
    {
        ok = [composeViewController setInitialText:tweetText];
        if(!ok){
            errorMessage = @"Tweet is too long";
        }
    }

    if(imageAttach != nil)
    {
        // Note that the image is loaded syncronously
        if([imageAttach hasPrefix:@"http://"]){
            UIImage *img = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imageAttach]]];
            ok = [composeViewController addImage:img];
        }
        else{
            ok = [composeViewController addImage:[UIImage imageNamed:imageAttach]];
        }
        if(!ok){
            errorMessage = @"Image could not be added";
        }
    }

    if(urlAttach != nil)
    {
        ok = [composeViewController addURL:[NSURL URLWithString:urlAttach]];
        if(!ok){
            errorMessage = @"URL too long";
        }
    }



    if(!ok)
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
    }
    else
    {
#if TARGET_IPHONE_SIMULATOR
        NSString *simWarning = @"Test TwitterPlugin on Real Hardware. Tested on Cordova 2.0.0";
        //EXC_BAD_ACCESS occurs on simulator unable to reproduce on real device
        //running iOS 5.1 and Cordova 1.6.1
        NSLog(@"%@",simWarning);
#endif

        [self.viewController presentViewController:composeViewController animated:YES completion:nil];
        [composeViewController setCompletionHandler:^(SLComposeViewControllerResult result) {
            // now check for availability of the app and invoke the correct callback
            if (SLComposeViewControllerResultDone == result) {
                CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:TRUE];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
            // required for iOS6 (issues #162 and #167)
            [self.viewController dismissViewControllerAnimated:YES completion:nil];
        }];
    }
}

- (void) sendTweet:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted == YES)
         {
             NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
             if ([arrayOfAccounts count] > 0)
             {
                 ACAccount *twitterAccount = [arrayOfAccounts lastObject];

                 NSMutableDictionary* options = (NSMutableDictionary*)[command argumentAtIndex:0];
                 NSString *rtwID = [options objectForKey:@"in_reply_to_status_id"];
                 NSString *tweetText = [options objectForKey:@"text"];

                 NSString *params =[NSString stringWithFormat:@"?status=%@", tweetText];
                 if(rtwID != nil){
                     params = [NSString stringWithFormat:@"%@&in_reply_to_status_id=%@",params,rtwID];
                 }
                 NSString *url = [NSString stringWithFormat:@"%@statuses/update.json%@", TWITTER_URL,params];

                 SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:url] parameters:nil];
                 aRequest.account = twitterAccount;

                 [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                     CDVPluginResult* pluginResult = nil;

                     if([urlResponse statusCode] == 200)
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSDictionary *dict = [dataString JSONObject];
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                     }
                     else
                     {
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                     }

                     [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                 }];
             }
             else
             {
                 CDVPluginResult* pluginResult = nil;
                 pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Account"];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
             }
         }
         else
         {
             CDVPluginResult* pluginResult = nil;
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Access Grated"];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
         }
     }];

}

- (void) getPublicTimeline:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted == YES)
         {
             NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
             if ([arrayOfAccounts count] > 0)
             {
                 ACAccount *twitterAccount = [arrayOfAccounts lastObject];

                 //public_timeline deprecated
                 NSString *url = [NSString stringWithFormat:@"%@statuses/home_timeline.json", TWITTER_URL];

                 SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:url] parameters:nil];
                 aRequest.account = twitterAccount;

                 [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                     CDVPluginResult* pluginResult = nil;

                     if([urlResponse statusCode] == 200)
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSDictionary *dict = [dataString JSONObject];
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                     }
                     else
                     {
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                     }

                     [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                 }];

             }
             else
             {
                 CDVPluginResult* pluginResult = nil;
                 pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Account"];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
             }
         }
         else
         {
             CDVPluginResult* pluginResult = nil;
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Access Grated"];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
         }
     }];
}

- (void) searchByHashtag:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted == YES)
         {
             NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
             if ([arrayOfAccounts count] > 0)
             {
                 ACAccount *twitterAccount = [arrayOfAccounts lastObject];

                 NSMutableDictionary* options = (NSMutableDictionary*)[command argumentAtIndex:0];
                 NSString *query = [options objectForKey:@"hashtag"];

                 //public_timeline deprecated
                 NSString *url = [NSString stringWithFormat:@"%@search/tweets.json?q=%%23%@", TWITTER_URL, query];

                 SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:url] parameters:nil];
                 aRequest.account = twitterAccount;

                 [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                     CDVPluginResult* pluginResult = nil;

                     if([urlResponse statusCode] == 200)
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSDictionary *dict = [dataString JSONObject];
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                     }
                     else
                     {
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                     }

                     [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                 }];

             }
             else
             {
                 CDVPluginResult* pluginResult = nil;
                 pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Account"];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
             }
         }
         else
         {
             CDVPluginResult* pluginResult = nil;
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Access Grated"];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
         }
     }];
}

- (void) getTwitterUsername:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
            NSString *username = twitterAccount.username;
            CDVPluginResult* pluginResult = nil;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:username];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }
    }];
}

- (void) getTwitterProfile:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    NSString *url = [NSString stringWithFormat:@"%@users/show.json", TWITTER_URL];

    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            if ([accountsArray count]>0){
                ACAccount *twitterAccount = [accountsArray objectAtIndex:0];
                NSString *username = twitterAccount.username;

                NSMutableDictionary *md = [NSMutableDictionary dictionary];
                md[@"screen_name"] = username;

                SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:url] parameters:md];

                [aRequest setAccount:[accountsArray objectAtIndex:0]];
                [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                    CDVPluginResult* pluginResult = nil;
                    if([urlResponse statusCode] == 200) {
                        NSDictionary *dict = [dataString JSONObject];
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                    }else{
                        if (![username isEqualToString:@""]){
                            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:username];
                        }else{
                            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                        }
                    }
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                }];
            }else{
                CDVPluginResult* pluginResult = nil;
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No twitter account set up.Add a new account going to Settings -> Twitter"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];

            }
        }else{
            CDVPluginResult* pluginResult = nil;
            NSString *error = [NSString stringWithFormat:@"Please allow %@ to access your twitter account. Go to Settings -> Twitter -> Enable %@.",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }
    }];
}

- (void) getMentions:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    NSString *url = [NSString stringWithFormat:@"%@statuses/mentions_timeline.json", TWITTER_URL];

    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [accountStore requestAccessToAccountsWithType:accountType  options:nil completion:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            // making assumption they only have one twitter account configured, should probably revist
            if([accountsArray count] > 0) {
                SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:url] parameters:nil];
                [aRequest setAccount:[accountsArray objectAtIndex:0]];
                [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    CDVPluginResult* pluginResult = nil;
                    if([urlResponse statusCode] == 200) {
                        NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                        NSDictionary *dict = [dataString JSONObject];
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                    }
                    else{
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                    }

                    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                }];
            }
            else{
                CDVPluginResult* pluginResult = nil;
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Twitter accounts available"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
            }
        }
        else{
            CDVPluginResult* pluginResult = nil;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Access to Twitter accounts denied by user"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }
    }];
}

- (void) getTWRequest:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    NSMutableDictionary* options = (NSMutableDictionary*)[command argumentAtIndex:0];
    NSString *urlSlug = [options objectForKey:@"url"];
    NSString *url = [NSString stringWithFormat:@"%@%@", TWITTER_URL, urlSlug];

    NSDictionary *params = [options objectForKey:@"params"] ?: nil;
    // We might want to safety check here that params is indeed a dictionary.

    NSString *reqMethod = [options objectForKey:@"requestMethod"] ?: @"";
    SLRequestMethod method;
    if ([reqMethod isEqualToString:@"POST"]) {
        method = SLRequestMethodPOST;
        NSLog(@"POST");
    }
    else if ([reqMethod isEqualToString:@"DELETE"]) {
        method = SLRequestMethodDELETE;
        NSLog(@"DELETE");
    }
    else {
        method = SLRequestMethodGET;
        NSLog(@"GET");
    }


    // We should probably store the chosen account as an instance variable so as to not request it for every request.

    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        if(granted) {
            NSArray *accountsArray = [accountStore accountsWithAccountType:accountType];
            // making assumption they only have one twitter account configured, should probably revist
            if([accountsArray count] > 0) {
                SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:method URL:[NSURL URLWithString:url] parameters:params];

                [aRequest setAccount:[accountsArray objectAtIndex:0]];
                [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    CDVPluginResult* pluginResult = nil;
                    if([urlResponse statusCode] == 200) {
                        NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                        NSDictionary *dict = [dataString JSONObject];
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                    }
                    else{
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                    }

                    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                }];
            }
            else{
                CDVPluginResult* pluginResult = nil;
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Twitter accounts available"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
            }
        }
        else{
            CDVPluginResult* pluginResult = nil;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Access to Twitter accounts denied by user"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
        }
    }];
}

- (void) reTweet:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted == YES)
         {
             NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
             if ([arrayOfAccounts count] > 0)
             {
                 ACAccount *twitterAccount = [arrayOfAccounts lastObject];

                 NSLog(@"arg_0: %@",[command.arguments objectAtIndex:0]);

                 NSString *RTWT_URL = [NSString stringWithFormat:@"statuses/retweet/%@.json",[command.arguments objectAtIndex:0]];
                 NSString *url = [NSString stringWithFormat:@"%@%@", TWITTER_URL,RTWT_URL];

                 NSLog(@"url: %@",url);

                 SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:[NSURL URLWithString:url] parameters:nil];
                 aRequest.account = twitterAccount;

                 [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                     CDVPluginResult* pluginResult = nil;

                     if([urlResponse statusCode] == 200)
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSDictionary *dict = [dataString JSONObject];
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                     }
                     else
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSLog(@"%@",dataString);
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                     }

                     [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                 }];

             }
             else
             {
                 CDVPluginResult* pluginResult = nil;
                 pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Account"];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
             }
         }
         else
         {
             CDVPluginResult* pluginResult = nil;
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Access Grated"];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
         }
     }];
}

- (void) addFavorites:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted == YES)
         {
             NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
             if ([arrayOfAccounts count] > 0)
             {
                ACAccount *twitterAccount = [arrayOfAccounts lastObject];
                NSLog(@"arg_0: %@",[command.arguments objectAtIndex:0]);
                NSString *FVT_URL = [NSString stringWithFormat:@"favorites/create.json?id=%@",[command.arguments objectAtIndex:0]];
                NSString *url = [NSString stringWithFormat:@"%@%@", TWITTER_URL,FVT_URL];
                NSLog(@"url: %@",url);

                SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:[NSURL URLWithString:url] parameters:nil];
                aRequest.account = twitterAccount;

                [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                    CDVPluginResult* pluginResult = nil;

                    if([urlResponse statusCode] == 200)
                    {
                        NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                        NSDictionary *dict = [dataString JSONObject];
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                    }
                    else
                    {
                        NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                        NSLog(@"%@",dataString);
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                    }

                    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                }];

             }
             else
             {
                 CDVPluginResult* pluginResult = nil;
                 pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Account"];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
             }
         }
         else
         {
             CDVPluginResult* pluginResult = nil;
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Access Grated"];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
         }
     }];
}

- (void) rmFavorites:(CDVInvokedUrlCommand*)command
{
    NSString *callbackId = command.callbackId;
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (granted == YES)
         {
             NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
             if ([arrayOfAccounts count] > 0)
             {
                 ACAccount *twitterAccount = [arrayOfAccounts lastObject];

                 NSLog(@"arg_0: %@",[command.arguments objectAtIndex:0]);
                 NSString *FVT_URL = [NSString stringWithFormat:@"favorites/destroy.json?id=%@",[command.arguments objectAtIndex:0]];
                 NSString *url = [NSString stringWithFormat:@"%@%@", TWITTER_URL,FVT_URL];
                 NSLog(@"url: %@",url);

                 SLRequest *aRequest  = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:[NSURL URLWithString:url] parameters:nil];
                 aRequest.account = twitterAccount;

                 [aRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                     CDVPluginResult* pluginResult = nil;

                     if([urlResponse statusCode] == 200)
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSDictionary *dict = [dataString JSONObject];
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                     }
                     else
                     {
                         NSString *dataString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                         NSLog(@"%@",dataString);
                         pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[urlResponse statusCode]];
                     }

                     [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
                 }];

             }
             else
             {
                 CDVPluginResult* pluginResult = nil;
                 pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Account"];
                 [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
             }
         }
         else
         {
             CDVPluginResult* pluginResult = nil;
             pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Twitter Access Grated"];
             [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
         }
     }];
}

// The JS must run on the main thread because you can't make a uikit call (uiwebview) from another thread (what twitter does for calls)
- (void) performCallbackOnMainThreadforJS:(NSString*)javascript{
    [super performSelectorOnMainThread:@selector(writeJavascript:) withObject:javascript waitUntilDone:YES];
}

@end

//
//  CSContext.h
//  Replete-MacOS
//
//  Created by Jason Jobe on 4/7/19.
//  Copyright © 2019 Jason Jobe. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CSContext : NSObject

-(void)initializeJavaScriptEnvironment;
-(void)setPrintCallback:(void (^)(BOOL, NSString*))printCallback;
-(void)setWidth:(int)width;
-(void)evaluate:(NSString*)text;
-(void)evaluate:(NSString*)text asExpression:(BOOL)expression;
-(NSArray*)parinferFormat:(NSString*)text pos:(int)pos enterPressed:(BOOL)enterPressed;
-(NSString*)getClojureScriptVersion;

@end

NS_ASSUME_NONNULL_END

//
//  RootViewController.m
//  KitTest
//
//  Created by Brian Wilson on 11/16/11.
//  Copyright (c) 2011-2012 Kinvey. All rights reserved.
//

#import "RootViewController.h"
#import "ImageViewController.h"
#import "KCSViewController.h"

@implementation RootViewController

@synthesize imageViewController=_imageViewController;
@synthesize viewController=_viewController;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)switchViews:(id)sender
{
    
//    if (self.yellowViewController == nil)
//    {
//        YellowViewController *yellowController = [[YellowViewController alloc]
//                                                  initWithNibName:@"YellowView" bundle:nil];
//        self.yellowViewController = yellowController;
//        [yellowController release];
//    }
    
    [UIView beginAnimations:@"View Flip" context:nil];
    [UIView setAnimationDuration:1.25];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    
    UIViewController *coming = nil;
    UIViewController *going = nil;
    UIViewAnimationTransition transition;
    
    if (self.imageViewController.view.superview == nil) 
    {   
        coming = self.imageViewController;
        going = self.viewController;
        transition = UIViewAnimationTransitionFlipFromLeft;
    }
    else
    {
        coming = self.viewController;
        going = self.imageViewController;
        transition = UIViewAnimationTransitionFlipFromRight;
    }
    
    [UIView setAnimationTransition: transition forView:self.view cache:YES];
    [coming viewWillAppear:YES];
    [going viewWillDisappear:YES];
    [going.view removeFromSuperview];
    [self.view insertSubview: coming.view atIndex:0];
    [going viewDidDisappear:YES];
    [coming viewDidAppear:YES];
    
    [UIView commitAnimations];
    
}


@end
//
//  ViewController.m
//  Interview02-读写安全
//
//  Created by MJ Lee on 2018/6/19.
//  Copyright © 2018年 MJ Lee. All rights reserved.
//

#import "ViewController.h"
#import <pthread/pthread.h>

@interface ViewController ()

@property(nonatomic, assign)pthread_rwlock_t lock;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
  pthread_rwlock_init(&_lock, NULL);
  
  dispatch_queue_t queue = dispatch_queue_create("fff",DISPATCH_QUEUE_CONCURRENT);
  
  for (int i = 0; i<10; i++) {
    dispatch_async(queue, ^{
      [self read];
    });
    dispatch_async(queue, ^{
      [self write];
    });
  }
  
}


- (void)read {
  pthread_rwlock_rdlock(&_lock);
  sleep(2);
  NSLog(@"%s", __func__);
  pthread_rwlock_unlock(&_lock);
 }

- (void)write
{
  pthread_rwlock_wrlock(&_lock);
  sleep(2);
  NSLog(@"%s", __func__);
  pthread_rwlock_unlock(&_lock);
 }

- (void)dealloc
{
  pthread_rwlock_destroy(&_lock);
 }


@end

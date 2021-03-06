## dispatch_semaphore

- semaphore叫做”信号量”
- 信号量的初始值，可以用来控制线程并发访问的最大数量
- 信号量的初始值为1，代表同时只允许1条线程访问资源，保证线程同步

注意：可以设置初始值最大并发线程数。



## @synchronized

* @syncronized是对mutex递归锁的封装。
* 源码查看：objc4中的objc-sync.mm文件
* @syncronzed(obj)内部会根据ob的地址通过hashmap找到j对应的递归锁，然后进行加锁，解锁操作。

 @synchronized(充当一把锁),如果传不同的对象，代表不同的锁，无法其他加锁的目的。

@synchronized(self ) {

​    [super  __drawMoney];

  }

作为递归锁，支持对递归方法进行加锁，如果不是递归锁，无法对递归方法进行加锁。

## iOS线程同步方案性能比较

性能从高到低

* os_unfair_lock (iOS10)
* osspinLock 
* Semaphore(iOS 8,推荐)
* mutexLock(跨平台，推荐)
* 

#### atomic

- atomic用于保证属性setter、getter的原子性操作，相当于在getter和setter内部加了线程同步的锁

  

  ```
  **@property** (**copy**, **atomic**) NSString *name;
  
  \- (**void**)setName:(NSString *)name
  
  {
  
    // 加锁
  
    _name = name;
  
    // 解锁
  
  }
  
  \- (NSString *)name
  
  {
  
  // 加锁
  
    **return** _name;
  
  // 解锁
  
  }
  ```

- 可以参考源码objc4的objc-accessors.mm

- 它并不能保证使用属性的过程是线程安全的

  ```
  [p.data addObject:@"1"];
  相当于
  nsmutablearry* arr = p.data;
  [arr addobject:@"1"]
  ```

- 为什么不经常用：太耗性能。

setter，getter调用频繁这样太耗费性能，如果非要加锁，可以在外边加锁

```objective-c
  for (int i = 0; i < 10; i++) {
     dispatch_async(NULL, ^{
       // 加锁
        p.data = [NSMutableArray array];
        // 解锁
       });
     } 

```

  

## 读写安全方案

#####  IO操作指的是文件的读写，如何实现

- 同一时间，只能有1个线程进行写的操作
- 同一时间，允许有多个线程进行读的操作
- 同一时间，不允许既有写的操作，又有读的操作

##### 上面的场景就是典型的“多读单写”，经常用于文件等数据的读写操作，iOS中的实现方案有

- pthread_rwlock：读写锁,会休眠

  ```
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
  ```

  

- dispatch_barrier_async：异步栅栏调用

​        这个函数传入的并发队列必须是自己通过dispatch_queue_cretate创建的.

​         如果传入的是一个串行或是一个全局的并发队列，那这个函数便等同于dispatch_async函数的效果

​	dispatch_async 开始时会建立一个栅栏，把任务单独隔离开来，类似于这样。

![image-20210713124025905](/Users/lumi/Library/Application Support/typora-user-images/image-20210713124025905.png)

```
#import "ViewController.h"
#import <pthread.h>

@interface ViewController ()
@property (strong, nonatomic) dispatch_queue_t queue;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    queue.maxConcurrentOperationCount = 5;
    
//    dispatch_semaphore_create(5);
    
    self.queue = dispatch_queue_create("rw_queue", DISPATCH_QUEUE_CONCURRENT);
    
    for (int i = 0; i < 10; i++) {
        dispatch_async(self.queue, ^{
            [self read];
        });
        
        dispatch_async(self.queue, ^{
            [self read];
        });
        
        dispatch_async(self.queue, ^{
            [self read];
        });
        
        dispatch_barrier_async(self.queue, ^{
            [self write];
        });
    }
}


- (void)read {
    sleep(1);
    NSLog(@"read %@",[NSThread currentThread].name);
}

- (void)write
{
    sleep(1);
    NSLog(@"write %@",[NSThread currentThread].name);
}

@end

打印如下：
2021-07-13 12:32:57.445451+0800 Interview02-读写安全[5004:4693665] read
2021-07-13 12:32:57.445451+0800 Interview02-读写安全[5004:4693671] read
2021-07-13 12:32:57.445451+0800 Interview02-读写安全[5004:4693667] read
2021-07-13 12:32:58.451043+0800 Interview02-读写安全[5004:4693667] write
2021-07-13 12:32:59.455399+0800 Interview02-读写安全[5004:4693667] read
2021-07-13 12:32:59.456514+0800 Interview02-读写安全[5004:4693665] read
2021-07-13 12:32:59.456509+0800 Interview02-读写安全[5004:4693671] read
2021-07-13 12:33:00.459304+0800 Interview02-读写安全[5004:4693671] write
2021-07-13 12:33:01.464516+0800 Interview02-读写安全[5004:4693671] read
2021-07-13 12:33:01.464726+0800 Interview02-读写安全[5004:4693665] read
2021-07-13 12:33:01.464748+0800 Interview02-读写安全[5004:4693667] read
2021-07-13 12:33:02.470105+0800 Interview02-读写安全[5004:4693667] write
2021-07-13 12:33:03.475656+0800 Interview02-
```

  思考：如果用栅栏函数来实现，多个网络请求完成刷新页面的需求，该怎么处理？

## 内存管理

#### NSTimer 和CADisplayLink

基于runloop实现的

对target对象强引用

```
@interface MJProxy : NSObject

+ (instancetype)proxyWithTarget:(id)target;
@property (weak, nonatomic) id target;

@end


+ (instancetype)proxyWithTarget:(id)target
{
    MJProxy *proxy = [MJProxy alloc];
    proxy.target = target;
    return proxy;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)sel{
  return [self.target methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation{
  [invocation invokeWithTarget:self.target];
}


self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:[MJProxy proxyWithTarget:self] selector:@selector(timerTest) userInfo:nil repeats:YES];

```

### GCD定时器更加准确

不依赖runloop，更加精确

自己封装一个gcd timer

```
@interface MJTimer : NSObject

+ (NSString *)execTask:(void(^)(void))task
           start:(NSTimeInterval)start
        interval:(NSTimeInterval)interval
         repeats:(BOOL)repeats
           async:(BOOL)async;

+ (NSString *)execTask:(id)target
              selector:(SEL)selector
                 start:(NSTimeInterval)start
              interval:(NSTimeInterval)interval
               repeats:(BOOL)repeats
                 async:(BOOL)async;

+ (void)cancelTask:(NSString *)name;

@end

@implementation MJTimer

static NSMutableDictionary *timers_;
dispatch_semaphore_t semaphore_;
+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timers_ = [NSMutableDictionary dictionary];
        semaphore_ = dispatch_semaphore_create(1);
    });
}

+ (NSString *)execTask:(void (^)(void))task start:(NSTimeInterval)start interval:(NSTimeInterval)interval repeats:(BOOL)repeats async:(BOOL)async
{
    if (!task || start < 0 || (interval <= 0 && repeats)) return nil;
    
    // 队列
    dispatch_queue_t queue = async ? dispatch_get_global_queue(0, 0) : dispatch_get_main_queue();
    
    // 创建定时器
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    // 设置时间
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, start * NSEC_PER_SEC),
                              interval * NSEC_PER_SEC, 0);
    
    
    dispatch_semaphore_wait(semaphore_, DISPATCH_TIME_FOREVER);
    // 定时器的唯一标识
    NSString *name = [NSString stringWithFormat:@"%zd", timers_.count];
    // 存放到字典中
    timers_[name] = timer;
    dispatch_semaphore_signal(semaphore_);
    
    // 设置回调
    dispatch_source_set_event_handler(timer, ^{
        task();
        
        if (!repeats) { // 不重复的任务
            [self cancelTask:name];
        }
    });
    
    // 启动定时器
    dispatch_resume(timer);
    
    return name;
}

+ (NSString *)execTask:(id)target selector:(SEL)selector start:(NSTimeInterval)start interval:(NSTimeInterval)interval repeats:(BOOL)repeats async:(BOOL)async
{
    if (!target || !selector) return nil;
    
    return [self execTask:^{
        if ([target respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [target performSelector:selector];
#pragma clang diagnostic pop
        }
    } start:start interval:interval repeats:repeats async:async];
}

+ (void)cancelTask:(NSString *)name
{
    if (name.length == 0) return;
    
    dispatch_semaphore_wait(semaphore_, DISPATCH_TIME_FOREVER);
    
    dispatch_source_t timer = timers_[name];
    if (timer) {
        dispatch_source_cancel(timer);
        [timers_ removeObjectForKey:name];
    }

    dispatch_semaphore_signal(semaphore_);
}

@end

```

### 内存分配

地址从低到高

* 代码段：编译后的代码
* 数据段:
  * 字符串常量
  * 初始化后的全局变量，静态变量
  * 未初始化后的全局变量，静态变量
* 堆空间
  * 内存从低到高分配
* 栈空间
  * 局部变量
  * 内存从高到低分配
* 内核区

验证过程如下

```

int a = 10;
int b;

int main(int argc, char * argv[]) {
    @autoreleasepool {
        static int c = 20;
        
        static int d;
        
        int e;
        int f = 20;

        NSString *str = @"123";
        
        NSObject *obj = [[NSObject alloc] init];
        
        NSLog(@"\n&a=%p\n&b=%p\n&c=%p\n&d=%p\n&e=%p\n&f=%p\nstr=%p\nobj=%p\n",
              &a, &b, &c, &d, &e, &f, str, obj);
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

/*
 字符串常量
 str=0x10dfa0068
 
 已初始化的全局变量、静态变量
 &a =0x10dfa0db8
 &c =0x10dfa0dbc
 
 未初始化的全局变量、静态变量
 &d =0x10dfa0e80
 &b =0x10dfa0e84
 
 堆
 obj=0x608000012210
 
 栈
 &f =0x7ffee1c60fe0
 &e =0x7ffee1c60fe4
 */

```







## 优化

[图片渲染过程](https://blog.csdn.net/TuGeLe/article/details/78599414)


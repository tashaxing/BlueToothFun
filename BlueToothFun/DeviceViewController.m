//
//  DeviceViewController.m
//  BlueToothFun
//
//  Created by yxhe on 16/12/5.
//  Copyright © 2016年 tashaxing. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "DeviceViewController.h"

// 自己造一些uuid，可以用mac terminal的uuidgen命令

#define kPeripheralName @"Tashaxing's device" // 外围设备名称
#define kServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE" // 服务的UUID
#define kCharacteristicNotifyUUID @"6666" // 特征的UUID
#define kCharacteristicReadUUID @"7777" 
#define kCharacteristicWriteUUID @"8888"

@interface DeviceViewController ()<CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBPeripheralManager *peripheralManager;

@property (nonatomic, strong) NSMutableArray *centralDeviceArray;

@property (nonatomic, strong) CBMutableCharacteristic *notifyCharacteristic;
@property (nonatomic, strong) CBMutableCharacteristic *readCharacteristic;
@property (nonatomic, strong) CBMutableCharacteristic *writeCharacteristic;

@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

@implementation DeviceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    // 启动外围设备管理器
    self.peripheralManager = [[CBPeripheralManager alloc] init];
    self.peripheralManager.delegate = self;
    
}

// 启动外围设备服务
- (IBAction)openBtn:(id)sender
{
    // 创建特征三种
    CBUUID *characteristicNotifyUUID = [CBUUID UUIDWithString:kCharacteristicNotifyUUID];
    CBMutableCharacteristic *characteristicNotify = [[CBMutableCharacteristic alloc] initWithType:characteristicNotifyUUID
                                                                                       properties:CBCharacteristicPropertyNotify
                                                                                            value:nil
                                                                                      permissions:CBAttributePermissionsReadable];
    
    CBUUID *characteristicReadUUID = [CBUUID UUIDWithString:kCharacteristicReadUUID];
    CBMutableCharacteristic *characteristicRead = [[CBMutableCharacteristic alloc] initWithType:characteristicReadUUID
                                                                                     properties:CBCharacteristicPropertyRead
                                                                                          value:nil
                                                                                    permissions:CBAttributePermissionsReadable];
    
    CBUUID *characteristicWriteUUID = [CBUUID UUIDWithString:kCharacteristicWriteUUID];
    CBMutableCharacteristic *characteristicWrite = [[CBMutableCharacteristic alloc] initWithType:characteristicWriteUUID
                                                                                     properties:CBCharacteristicPropertyWrite
                                                                                          value:nil
                                                                                    permissions:CBAttributePermissionsWriteable];
    
    // 存储这些特征
    self.notifyCharacteristic = characteristicNotify;
    self.readCharacteristic = characteristicRead;
    self.writeCharacteristic = characteristicWrite;
    
    // 创建服务
    CBUUID *serviceUUID=[CBUUID UUIDWithString:kServiceUUID];
    CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
    [service setCharacteristics:@[characteristicNotify, characteristicRead, characteristicWrite]]; // 可以多个
    
    // 添加服务（可以添加多个）
    [self.peripheralManager addService:service];
}

- (IBAction)writeBtn:(id)sender
{
    // 改变特征值
    NSString *str = _textField.text;
    NSString *strNotify = [NSString stringWithFormat:@"%@notify", str];
    NSString *strRead = [NSString stringWithFormat:@"%@read", str];
    NSString *strwrite = [NSString stringWithFormat:@"%@write", str];
    
    NSData *dataNotify = [strNotify dataUsingEncoding:NSUTF8StringEncoding];
    NSData *dataRead = [strRead dataUsingEncoding:NSUTF8StringEncoding];
    NSData *dataWrite = [strwrite dataUsingEncoding:NSUTF8StringEncoding];
    
    // 先写本地
    self.notifyCharacteristic.value = dataNotify;
    self.readCharacteristic.value = dataRead;
    self.writeCharacteristic.value = dataWrite;
    
    // 再更新notify
    [self.peripheralManager updateValue:dataNotify
                      forCharacteristic:_notifyCharacteristic
                   onSubscribedCentrals:nil];

    
}


#pragma mark - 外围设备代理方法
// 生成后就调用
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state)
    {
        case CBManagerStatePoweredOn:
            NSLog(@"蓝牙已打开");
            
            break;
            
        default:
            NSLog(@"此设备不支持BLE或未打开蓝牙功能，无法作为外围设备.");
            break;
    }
}

// 外围设备添加服务后回调
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"向外围设备添加服务失败，错误详情：%@", error.localizedDescription);
        return;
    }
    
    // 添加服务后开始广播
    NSDictionary *dict = @{CBAdvertisementDataLocalNameKey:kPeripheralName}; // 广播设置
    [self.peripheralManager startAdvertising:dict]; // 开始广播
    NSLog(@"向外围设备添加了服务并开始广播...");
}

// 启动广播回调
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (error)
    {
        NSLog(@"启动广播过程中发生错误，错误信息：%@", error.localizedDescription);
        return;
    }
    NSLog(@"启动广播...");
}

// 有中央设备订阅特征
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"中心设备：%@ 已订阅特征：%@", central, characteristic);

    //发现中心设备并存储
    if (![self.centralDeviceArray containsObject:central])
    {
        [self.centralDeviceArray addObject:central];
    }
}

// 取消订阅特征
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"中心设备：%@ 取消订阅特征：%@.", central, characteristic);
}

// 读characteristics请求
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"didReceiveReadRequest");
    // 判断是否有读数据的权限
    if (request.characteristic.properties & CBCharacteristicPropertyRead)
    {
        NSData *data = request.characteristic.value;
        [request setValue:data];
        
        // 对请求作出成功响应
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    }
    else
    {
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }
}

// 写characteristics请求
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    NSLog(@"didReceiveWriteRequests");
    
    // 默认现取第一个请求
    CBATTRequest *request = requests[0];
    
    // 判断是否有写数据的权限
    if (request.characteristic.properties & CBCharacteristicPropertyWrite) {
        
        // 需要转换成CBMutableCharacteristic对象才能进行写值
        CBMutableCharacteristic *c =(CBMutableCharacteristic *)request.characteristic;
        c.value = request.value; // 这一行已更改了对应特征的值了
        
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    }
    else
    {
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }
    
    
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict
{
    NSLog(@"willRestoreState");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end

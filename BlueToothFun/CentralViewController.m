//
//  CentralViewController.m
//  BlueToothFun
//
//  Created by yxhe on 16/12/5.
//  Copyright © 2016年 tashaxing. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "CentralViewController.h"

// 跟外围设备协商好 服务 和 特征 的uuid接口
#define kServiceUUID @"180D" // 服务的UUID
#define kCharacteristicUUID @"2A37" // 特征的UUID

@interface CentralViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *connectedDevice;
@property (nonatomic, strong) NSMutableArray *deviceArray;
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;

@property (weak, nonatomic) IBOutlet UITextField *textView;


@end

@implementation CentralViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // tableview
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // devices
    self.deviceArray = [[NSMutableArray alloc] init];
    
    // central
    self.centralManager = [[CBCentralManager alloc] init];
    self.centralManager.delegate = self;
}

#pragma mark - 蓝牙代理
// 只要中心管理者初始化 就会触发此代理方法 判断手机蓝牙状态
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state)
    {
        case 0:
            NSLog(@"CBCentralManagerStateUnknown");
            break;
        case 1:
            NSLog(@"CBCentralManagerStateResetting");
            break;
        case 2:
            NSLog(@"CBCentralManagerStateUnsupported"); // 不支持蓝牙
            break;
        case 3:
            NSLog(@"CBCentralManagerStateUnauthorized");
            break;
        case 4:
        {
            NSLog(@"CBCentralManagerStatePoweredOff"); // 蓝牙未开启
        }
            break;
        case 5:
        {
            NSLog(@"CBCentralManagerStatePoweredOn"); // 蓝牙已开启
        }
            break;
        default:
            break;
    }
}

// 扫描后调用这个方法
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    if (peripheral == nil||peripheral.identifier == nil || peripheral.name == nil)
    {
        return;
    }
    
    // 搜到设备
    [self.deviceArray addObject:peripheral];
    NSLog(@"%@", peripheral); // uuid, name, state
    
    [self.tableView reloadData];
}

// connectPeripheral回调 成功或者失败
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"%@", peripheral);
    
    // 大概获取服务和特征
    [peripheral discoverServices:nil];
    
    
    // 停止扫描
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@", peripheral);
    NSLog(@"%@", error.localizedDescription);
}

// discoverServices后，获取当前设备服务services
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }
    
    NSLog(@"所有的services %@", peripheral.services);
    
    // 遍历所有service
    for (CBService *service in peripheral.services)
    {
        // 找到你需要的servicesuuid
//        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]])
        if ([service.UUID.UUIDString isEqualToString:kServiceUUID])
        {
            // 监听它
            [peripheral discoverCharacteristics:nil forService:service];
        }
        
    }
    
}

// discoverCharacteristics for service后，获取特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Discovered characteristics for %@ with error: %@", service.UUID, [error localizedDescription]);
        return;
    }
    
    NSLog(@"服务：%@", service.UUID);
    
    // 特征
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        NSLog(@"特征描述：%@", characteristic.description);
        
        // 根据特征不同属性去读取或者写（特征已用位运算组合）
        if (characteristic.properties == CBCharacteristicPropertyRead)
        {
            // 读特征
            [peripheral readValueForCharacteristic:characteristic];
            NSLog(@"%@", characteristic); // 此时已经读到数据了
        }
        else if (characteristic.properties == (CBCharacteristicPropertyWrite | CBCharacteristicPropertyExtendedProperties))
        {
            // 写特征(有回调和无回调两种)
            NSData *data = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
            self.writeCharacteristic = characteristic;
            [peripheral writeValue:data
                 forCharacteristic:characteristic
                              type:CBCharacteristicWriteWithResponse];
        }
        else if (characteristic.properties == CBCharacteristicPropertyNotify)
        {
            // 可以根据uuid去监听特征，这种特征一般是间隔多长时间持续刷新并通知的，比如心跳
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]])
            {
                // 监听特征
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
        }
    }
}

// writeValue， 写特征的回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    NSLog(@"write success");
}

// setNotifyValue之后,更新特征的value的时候会调用 （凡是从蓝牙传过来的数据都要经过这个回调，简单的说这个方法就是你拿数据的唯一方法） 你可以判断是否
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    NSLog(@"特征描述：%@", characteristic.description);
    
}


#pragma mark - 按钮
// 扫描
- (IBAction)scanBtn:(id)sender
{
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    [self.deviceArray removeAllObjects];
}

// 写入
- (IBAction)writeBtn:(id)sender
{
    NSData *data = [_textView.text dataUsingEncoding:NSUTF8StringEncoding];
    [self.connectedDevice writeValue:data
                   forCharacteristic:self.writeCharacteristic
                                type:CBCharacteristicWriteWithResponse];
}

#pragma mark - 列表代理
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"DeviceCell"];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DeviceCell"];
    }
    
    // 将蓝牙外设对象接出，取出name，显示
    CBPeripheral *device = (CBPeripheral *)_deviceArray[indexPath.row];
    NSString *deviceName = device.name;
    cell.textLabel.text = deviceName;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _deviceArray.count;;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.connectedDevice = _deviceArray[indexPath.row];
    self.connectedDevice.delegate = self;
    
    // 连接
    [self.centralManager connectPeripheral:self.connectedDevice
                                   options:@{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES}];
    
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end

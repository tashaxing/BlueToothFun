//
//  CentralViewController.m
//  BlueToothFun
//
//  Created by yxhe on 16/12/5.
//  Copyright © 2016年 tashaxing. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "CentralViewController.h"

#define kServiceUUID @"180D" // 服务的UUID
#define kCharacteristicUUID @"2A37" // 特征的UUID

@interface CentralViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *connectedDevice;
@property (nonatomic, strong) NSMutableArray *deviceArray;



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
    
    NSLog(@"所有的servicesUUID%@", peripheral.services);
    
    // 遍历所有service
    for (CBService *service in peripheral.services)
    {
        
        NSLog(@"服务%@", service.UUID);
        
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
        NSLog(@"%@", characteristic.UUID);
        
        // 发现特征,监听多个特征值
        // 注意：uuid 分为可读，可写，要区别对待！！！
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]])
        {
            NSLog(@"监听：%@", characteristic); // 监听特征
            //保存characteristic特征值对象
            //以后发信息也是用这个uuid
            
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
    }
}

// setNotifyValue后调用
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    NSLog(@"特征描述：%@", characteristic.description);
    NSLog(@"收到的数据：%@",characteristic.value);
    
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

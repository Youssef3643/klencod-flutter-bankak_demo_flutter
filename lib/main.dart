import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const red = Color(0xFFE50916);
const deepRed = Color(0xFFB5122B);
const green = Color(0xFF278C2C);
const green2 = Color(0xFF55A915);
const ink = Color(0xFF333333);
const bg = Color(0xFFF5F5F5);
const appTitle = 'Bankak Demo';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en';
  runApp(const BankakDemoApp());
}

class BankakDemoApp extends StatefulWidget {
  const BankakDemoApp({super.key});
  @override
  State<BankakDemoApp> createState() => _BankakDemoAppState();
}
class _BankakDemoAppState extends State<BankakDemoApp> {
  bool english = false;
  void toggleLanguage() => setState(() => english = !english);
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: appTitle,
    theme: ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(seedColor: red),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFBDBDBD)), borderRadius: BorderRadius.all(Radius.circular(9))),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: red, width: 1.5), borderRadius: BorderRadius.all(Radius.circular(9))),
      ),
    ),
    home: AppController(english: english, onLanguage: toggleLanguage),
  );
}

class AppController extends StatefulWidget {
  final bool english;
  final VoidCallback onLanguage;
  const AppController({super.key, required this.english, required this.onLanguage});
  @override
  State<AppController> createState() => _AppControllerState();
}
class _AppControllerState extends State<AppController> {
  Map<String,dynamic> users = {};
  Map<String,dynamic>? user;
  List<Map<String,dynamic>> transactions = [];
  List<Map<String,dynamic>> beneficiaries = [];
  bool loading = true;
  bool processing = false;
  String screen = 'login';
  Map<String,dynamic>? selectedTx;

  bool get en => widget.english;
  String t(String ar, String eng) => en ? eng : ar;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    users = jsonDecode(p.getString('users') ?? '{}').cast<String,dynamic>();
    final saved = p.getString('active_user');
    if (saved != null && users.containsKey(saved)) {
      user = Map<String,dynamic>.from(users[saved]);
      transactions = _list(users[saved]['transactions']);
      beneficiaries = _list(users[saved]['beneficiaries']);
      screen = 'home';
    }
    if (mounted) setState(() => loading = false);
  }
  List<Map<String,dynamic>> _list(dynamic v) => (v as List? ?? []).map((e)=>Map<String,dynamic>.from(e)).toList();
  Future<void> _save() async {
    if (user != null) {
      user!['transactions'] = transactions;
      user!['beneficiaries'] = beneficiaries;
      users[user!['account'].toString()] = user;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('users', jsonEncode(users));
    if (user != null) await p.setString('active_user', user!['account'].toString());
  }
  double get balance => (user?['balance'] as num?)?.toDouble() ?? 0;
  String money(num n) => '${NumberFormat('#,##0.00').format(n)} ${t('جنيه سوداني','SDG')}';
  String ref(String account) => '10030$account' '0001';
  String now() => DateFormat('dd-MMM-yyyy HH:mm:ss').format(DateTime.now());
  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), backgroundColor: deepRed));
  Future<void> waitProcessing() async {
    setState(() => processing = true);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (mounted) setState(() => processing = false);
  }
  Future<void> register(String name, String password) async {
    final account = '2${DateTime.now().microsecondsSinceEpoch.toString().substring(8,14)}';
    final newUser = {'name':name,'password':password,'account':account,'balance':5000.0,'transactions':[],'beneficiaries':[]};
    users[account] = newUser;
    user = Map<String,dynamic>.from(newUser);
    transactions = []; beneficiaries = [];
    await _save();
    setState(() => screen = 'home');
  }
  Future<void> login(String account, String password) async {
    final found = users[account];
    if (found == null || found['password'] != password) { toast(t('رقم الحساب أو كلمة المرور غير صحيحة','Incorrect account number or password')); return; }
    user = Map<String,dynamic>.from(found);
    transactions = _list(found['transactions']); beneficiaries = _list(found['beneficiaries']);
    await _save();
    setState(() => screen = 'home');
  }
  Future<void> logout() async {
    await _save();
    setState(() => screen = 'summary');
  }
  Future<void> closeSummary() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('active_user');
    user = null; transactions = []; beneficiaries = [];
    setState(() => screen = 'login');
  }
  void addTx(Map<String,dynamic> tx) {
    transactions.insert(0, tx);
    user!['transactions'] = transactions;
    user!['balance'] = balance - (tx['type'] == 'تحويل' ? (tx['amount'] as num).toDouble() : 0);
    _save();
  }
  Future<void> topUp(double amount) async {
    if (amount <= 0 || amount > 3000000) { toast(t('المبلغ يجب أن يكون بين 1 و3,000,000 جنيه','Amount must be between 1 and 3,000,000 SDG')); return; }
    setState(() => processing = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    user!['balance'] = balance + amount;
    transactions.insert(0, {'id':DateTime.now().millisecondsSinceEpoch.toString(),'date':now(),'type':'استلام أموال تجريبية','amount':amount,'from':'محاكاة شحن الرصيد','to':user!['account'],'name':user!['name'],'status':'ناجح','comment':'شحن تجريبي'});
    await _save();
    if (mounted) setState(() {processing = false; screen='receipt'; selectedTx=transactions.first;});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child:CircularProgressIndicator(color:red)));
    return Directionality(textDirection: en ? TextDirection.ltr : TextDirection.rtl,
      child: Stack(children:[
        Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds:320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.025, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child:_page(),
          ),
        ),
        if (processing) Positioned.fill(child: Container(color:Colors.black54, child:Center(child:Column(mainAxisSize:MainAxisSize.min, children:[
          const SizedBox(width:56,height:56,child:CircularProgressIndicator(color:Colors.white,strokeWidth:4)),
          const SizedBox(height:18), Text(t('معالجة','Processing'),style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w500))
        ]))))
      ])
    );
  }
  Widget _page() {
    switch(screen) {
      case 'login': return LoginPage(key:const ValueKey('login'), en:en,onLanguage:widget.onLanguage,onLogin:login,onRegister:()=>setState(()=>screen='register'));
      case 'register': return RegisterPage(key:const ValueKey('register'),en:en,onBack:()=>setState(()=>screen='login'),onCreate:register);
      case 'home': return HomePage(key:const ValueKey('home'),en:en,user:user!,balance:balance,onOpen:(s)=>setState(()=>screen=s),onLogout:logout,onTopUp:()=>setState(()=>screen='topup'));
      case 'account': return AccountPage(key:const ValueKey('account'),en:en,user:user!,balance:balance,onBack:()=>setState(()=>screen='home'));
      case 'transferMenu': return TransferMenu(key:const ValueKey('transferMenu'),en:en,onBack:()=>setState(()=>screen='home'),onDirect:()=>setState(()=>screen='direct'),onBeneficiary:()=>setState(()=>screen='beneficiaries'));
      case 'direct': return DirectPage(key:const ValueKey('direct'),en:en,onBack:()=>setState(()=>screen='transferMenu'),onContinue:(acc)=>_verifyAccount(acc));
      case 'confirmTransfer': return ConfirmTransferPage(key:const ValueKey('confirmTransfer'),en:en,account:_pendingAccount,name:_pendingName,onBack:()=>setState(()=>screen='direct'),onConfirm:_doTransfer);
      case 'beneficiaries': return BeneficiariesPage(key:const ValueKey('beneficiaries'),en:en,items:beneficiaries,onBack:()=>setState(()=>screen='transferMenu'),onAdd:(a,n) async {beneficiaries.add({'account':a,'name':n}); await _save(); setState((){});});
      case 'history': return HistoryPage(key:const ValueKey('history'),en:en,items:transactions,onBack:()=>setState(()=>screen='home'),onSelect:(tx){selectedTx=tx;setState(()=>screen='transaction');});
      case 'transaction': return TransactionPage(key:const ValueKey('transaction'),en:en,tx:selectedTx!,onBack:()=>setState(()=>screen='history'));
      case 'receipt': return ReceiptPage(key:const ValueKey('receipt'),en:en,tx:selectedTx!,onOk:()=>setState(()=>screen='home'),onNew:()=>setState(()=>screen='transferMenu'));
      case 'topup': return TopUpPage(key:const ValueKey('topup'),en:en,onBack:()=>setState(()=>screen='home'),onSubmit:topUp);
      case 'summary': return SummaryPage(key:const ValueKey('summary'),en:en,user:user!,transactions:transactions,onClose:closeSummary);
      default: return LoginPage(en:en,onLanguage:widget.onLanguage,onLogin:login,onRegister:()=>setState(()=>screen='register'));
    }
  }
  String _pendingAccount='', _pendingName='';
  void _verifyAccount(String acc) {
    final exists = users[acc];
    if (exists == null) { toast(t('الحساب غير موجود في المحاكاة','Account not found in this demo')); return; }
    _pendingAccount=acc; _pendingName=exists['name'];
    setState(()=>screen='confirmTransfer');
  }
  Future<void> _doTransfer(String amountText,String comment) async {
    final amount=double.tryParse(amountText.replaceAll(',',''))??0;
    if(amount<=0 || amount>3000000){toast(t('أدخل مبلغاً بين 1 و3,000,000 جنيه','Enter an amount between 1 and 3,000,000 SDG'));return;}
    if(amount>balance){toast(t('الرصيد التجريبي غير كافٍ','Insufficient demo balance'));return;}
    if(_pendingAccount==user!['account']){toast(t('لا يمكن التحويل إلى الحساب نفسه','Cannot transfer to the same account'));return;}
    setState(()=>processing=true);
    await Future.delayed(const Duration(milliseconds:1500));
    final recipient=Map<String,dynamic>.from(users[_pendingAccount]);
    final id=DateTime.now().millisecondsSinceEpoch.toString().substring(3);
    user!['balance']=balance-amount;
    recipient['balance']=(recipient['balance'] as num).toDouble()+amount;
    final tx={'id':id,'date':now(),'type':'تحويل إلى حساب آخر','amount':amount,'from':ref(user!['account']),'to':ref(_pendingAccount),'name':recipient['name'],'status':'ناجح','comment':comment.isEmpty?'N/A':comment};
    transactions.insert(0,tx);
    recipient['transactions']=_list(recipient['transactions'])..insert(0,{'id':id,'date':now(),'type':'استلام تحويل تجريبي','amount':amount,'from':ref(user!['account']),'to':ref(_pendingAccount),'name':user!['name'],'status':'ناجح','comment':comment.isEmpty?'N/A':comment});
    users[_pendingAccount]=recipient;
    await _save();
    if(mounted) setState(() {
      processing = false;
      selectedTx = tx;
      screen = 'receipt';
    });
  }
}

class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key,this.size=1});
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Text('بنكك',style:TextStyle(color:Colors.white,fontSize:42*size,fontWeight:FontWeight.w900,height:.9,letterSpacing:-2)),
    Row(mainAxisSize:MainAxisSize.min,children:[Text('b',style:TextStyle(color:const Color(0xFFB6A12B),fontSize:32*size,fontWeight:FontWeight.w900)),Text('ankak',style:TextStyle(color:Colors.white,fontSize:32*size,fontWeight:FontWeight.w900))])
  ]);
}
class BrandHeader extends StatelessWidget {
  final bool en; final bool home; final VoidCallback? onPower;
  const BrandHeader({super.key,required this.en,this.home=false,this.onPower});
  @override Widget build(BuildContext context)=>Container(height:112,color:red,child:Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFFF0808),Color(0xFFB5122B)],begin:Alignment.topCenter,end:Alignment.bottomCenter)),child:Stack(alignment:Alignment.center,children:[
    const Logo(size:.78),
    const Positioned(bottom:5,child:Text('DEMO • محاكاة تجريبية',style:TextStyle(color:Colors.white70,fontSize:9,letterSpacing:1))),
    if(home) Positioned(left:20,child:IconButton(onPressed:onPower,icon:const Icon(Icons.power_settings_new,color:Colors.white,size:43))),
    if(home) const Positioned(right:25,child:Icon(Icons.notifications_none,color:Colors.white,size:37)),
    if(!home) const Positioned(right:22,child:Icon(Icons.menu,color:Colors.white,size:39))
  ])));
}
class BackTitle extends StatelessWidget {
  final String title; final VoidCallback onBack;
  const BackTitle(this.title,this.onBack,{super.key});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.fromLTRB(16,18,18,22),child:Row(children:[
    Expanded(child:Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:27,color:ink))),
    InkWell(onTap:onBack,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:deepRed,width:2),borderRadius:BorderRadius.circular(10),boxShadow:[const BoxShadow(color:Colors.black26,blurRadius:4)]),child:Text('‹ ${Directionality.of(context)==TextDirection.rtl?'رجوع':'Back'}',style:const TextStyle(color:deepRed,fontSize:19))))
  ]));
}
class GlossButton extends StatelessWidget {
  final String text; final VoidCallback onTap; final double height; final IconData? icon;
  const GlossButton(this.text,this.onTap,{super.key,this.height=62,this.icon});
  @override Widget build(BuildContext context)=>InkWell(onTap:onTap,borderRadius:BorderRadius.circular(12),child:Container(height:height,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF8D1726),width:2),boxShadow:[const BoxShadow(color:Colors.black38,blurRadius:4,offset:Offset(0,3))],gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFFFFF1F1),Color(0xFFD21D2C),Color(0xFFFF1010),Color(0xFFDA0000)])),child:Center(child:Row(mainAxisSize:MainAxisSize.min,children:[if(icon!=null)Icon(icon,color:Colors.white),if(icon!=null)const SizedBox(width:8),Text(text,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w500))]))));
}
class Field extends StatelessWidget {
 final String hint; final TextEditingController controller; final TextInputType? keyboard; final bool obscure; final Widget? prefix;
 const Field(this.hint,this.controller,{super.key,this.keyboard,this.obscure=false,this.prefix});
 @override Widget build(BuildContext context)=>TextField(controller:controller,keyboardType:keyboard,obscureText:obscure,decoration:InputDecoration(hintText:hint,prefixIcon:prefix,contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:19)));
}

class LoginPage extends StatelessWidget {
 final bool en; final VoidCallback onLanguage; final Function(String,String) onLogin; final VoidCallback onRegister;
 const LoginPage({super.key,required this.en,required this.onLanguage,required this.onLogin,required this.onRegister});
 @override Widget build(BuildContext context){
  final a=TextEditingController(),p=TextEditingController();
  return Scaffold(body:Column(children:[
   Container(height:350,decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFFF0808),Color(0xFFB5122B)],begin:Alignment.topCenter,end:Alignment.bottomCenter)),child:SafeArea(child:Column(children:[
    Align(alignment:Alignment.topLeft,child:TextButton(onPressed:onLanguage,child:const Text('A / ع',style:TextStyle(color:Colors.white,fontSize:20)))),
    const Spacer(),const Logo(size:1.45),const SizedBox(height:8),const Text('DEMO • محاكاة تجريبية',style:TextStyle(color:Colors.white70,fontSize:11,letterSpacing:1)),const Spacer(),
   ]))),
   Transform.translate(offset:const Offset(0,-1),child:Container(color:bg,padding:const EdgeInsets.fromLTRB(28,0,28,20),child:Column(children:[
    const SizedBox(height:20),Field(en?'Account number (7 digits)':'أدخل رقم الحساب (7 أرقام)',a,keyboard:TextInputType.number,prefix:const Icon(Icons.person_outline)),
    const SizedBox(height:16),Field(en?'Password':'أدخل كلمة المرور',p,obscure:true,prefix:const Icon(Icons.visibility_off_outlined)),
    const SizedBox(height:28),GlossButton(en?'Login':'تسجيل الدخول',()=>onLogin(a.text.trim(),p.text),height:66),
    const SizedBox(height:32),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[TextButton(onPressed:onRegister,child:Text(en?'Register new?':'تسجيل جديد؟',style:const TextStyle(color:Colors.black54,fontSize:19))),TextButton(onPressed:()=>_showDemoInfo(context,en),child:Text(en?'Cannot login?':'لا تستطيع تسجيل الدخول؟',style:const TextStyle(color:Colors.black54,fontSize:17)))]),
    TextButton.icon(onPressed:()=>_showDemoInfo(context,en),icon:const Icon(Icons.qr_code,color:deepRed),label:Text(en?'Demo top-up code':'شارك الرمز (شحن تجريبي)',style:const TextStyle(color:Colors.black54,fontSize:19))),
    const SizedBox(height:30),
    const Spacer(),Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_footerIcon(Icons.chevron_left,'بنك الخرطوم'),_footerIcon(Icons.location_on,'مواقعنا'),_footerIcon(Icons.call,'المساعدة'),_footerIcon(Icons.facebook,'فيس بوك')])
   ])))
  ]));
 }
 static Widget _footerIcon(IconData i,String s)=>Column(children:[CircleAvatar(backgroundColor:green2,radius:25,child:Icon(i,color:Colors.white,size:28)),const SizedBox(height:5),Text(s,style:const TextStyle(color:Colors.black54))]);
}
void _showDemoInfo(BuildContext c,bool en)=>showDialog(context:c,builder:(_)=>AlertDialog(title:Text(en?'Demo only':'محاكاة تجريبية فقط'),content:Text(en?'This app is not connected to any real bank.':'هذا التطبيق غير متصل بأي بنك حقيقي. شحن الرصيد يتم من داخل الحساب التجريبي فقط.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:Text(en?'OK':'موافق'))]));

class RegisterPage extends StatelessWidget {
 final bool en; final VoidCallback onBack; final Function(String,String) onCreate;
 const RegisterPage({super.key,required this.en,required this.onBack,required this.onCreate});
 @override Widget build(BuildContext context){
  final n=TextEditingController(),p=TextEditingController(),p2=TextEditingController();
  return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Create account':'تسجيل جديد',onBack),Padding(padding:const EdgeInsets.all(22),child:Column(children:[
   Field(en?'Full name':'الاسم الثلاثي',n),const SizedBox(height:14),Field(en?'Password':'كلمة المرور',p,obscure:true),const SizedBox(height:14),Field(en?'Confirm password':'تأكيد كلمة المرور',p2,obscure:true),const SizedBox(height:22),
   GlossButton(en?'Create account':'إنشاء الحساب',(){if(n.text.trim().split(RegExp(r'\s+')).length<3){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(en?'Enter your full three-part name':'يرجى كتابة الاسم الثلاثي')));return;}if(p.text.length<4||p.text!=p2.text){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(en?'Check password':'تأكد من كلمة المرور')));return;}onCreate(n.text.trim(),p.text);}),
   const SizedBox(height:16),Text(en?'Starting demo balance: 5,000 SDG':'الرصيد الابتدائي التجريبي: 5,000 جنيه سوداني',style:const TextStyle(color:green,fontSize:18))
  ]))]));
 }
}
class HomePage extends StatelessWidget {
 final bool en; final Map<String,dynamic> user; final double balance; final Function(String) onOpen; final VoidCallback onLogout,onTopUp;
 const HomePage({super.key,required this.en,required this.user,required this.balance,required this.onOpen,required this.onLogout,required this.onTopUp});
 @override Widget build(BuildContext context){
  final items=[['تحويلات','Transfers',Icons.currency_exchange,'transferMenu'],['دفع فواتير','Bill payment',Icons.description,'topup'],['تفاصيل الحساب','Account details',Icons.person,'account'],['سحب بدون بطاقة','Cardless withdrawal',Icons.atm,'topup'],['بنكك PAY','Bankak PAY',Icons.qr_code,'topup'],['طلب الودائع الاستثمارية','Investment deposits',Icons.savings,'topup'],['إدارة المستفيدين','Beneficiaries',Icons.person_add,'beneficiaries'],['المعاملات السابقة','Previous transactions',Icons.calendar_month,'history'],['إدارة البطاقات','Cards',Icons.credit_card,'topup'],['طلبات','Requests',Icons.edit_note,'topup'],['أمر دفع دائم','Standing order',Icons.checklist,'topup'],['الضبط','Settings',Icons.settings,'topup'],['التجارة الإلكترونية','E-commerce',Icons.shopping_cart,'topup'],['خدمات العملات الأجنبية','FX services',Icons.currency_exchange,'topup']];
  return Scaffold(body:Column(children:[BrandHeader(en:en,home:true,onPower:onLogout),Expanded(child:SingleChildScrollView(child:Column(children:[
   Padding(padding:const EdgeInsets.fromLTRB(20,18,20,22),child:Row(children:[Text(en?'Good evening,':'مساء الخير،',style:const TextStyle(fontSize:22)),const SizedBox(width:8),Text(user['name'].toString().split(' ').first,style:const TextStyle(fontSize:22,color:ink))])),
   Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Wrap(spacing:16,runSpacing:24,children:items.map((it)=>SizedBox(width:(MediaQuery.of(context).size.width-64)/3,child:InkWell(onTap:()=>onOpen(it[3] as String),child:Column(children:[
    Container(height:88,decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),border:Border.all(color:deepRed,width:2),boxShadow:[const BoxShadow(color:Colors.black38,blurRadius:5,offset:Offset(0,4))],gradient:const LinearGradient(colors:[Color(0xFFFFEDED),Color(0xFFDF1A2C),Color(0xFFEE0000)],begin:Alignment.topCenter,end:Alignment.bottomCenter)),child:Icon(it[2] as IconData,color:Colors.white,size:46)),
    const SizedBox(height:8),Text(en?it[1] as String:it[0] as String,textAlign:TextAlign.center,style:const TextStyle(fontSize:17,color:Colors.black87,height:1.2))
   ])))).toList())),
   const SizedBox(height:24),Container(width:double.infinity,color:const Color(0xFFE7E7E7),padding:const EdgeInsets.all(14),child:Column(children:[Text(en?'Demo available balance':'الرصيد التجريبي المتاح',style:const TextStyle(color:ink)),Text(NumberFormat('#,##0.00').format(balance),style:const TextStyle(color:green,fontSize:25,fontWeight:FontWeight.bold)),Text(en?'SDG — simulated only':'جنيه سوداني — رصيد وهمي',style:const TextStyle(color:Colors.black54))]))
  ]))) ]));
 }
}
class AccountPage extends StatelessWidget {
 final bool en;final Map<String,dynamic> user;final double balance;final VoidCallback onBack;
 const AccountPage({super.key,required this.en,required this.user,required this.balance,required this.onBack});
 @override Widget build(BuildContext context)=>Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Account details':'تفاصيل الحساب',onBack),Card(margin:const EdgeInsets.all(18),child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
  const Icon(Icons.savings,color:deepRed,size:55),Text(en?'Savings account':'حساب توفير',style:const TextStyle(color:deepRed,fontSize:24,fontWeight:FontWeight.bold)),
  _line(en?'Account number':'رقم الحساب',user['account'].toString()),_line(en?'Reference number':'الرقم المرجعي',_ref(user['account'].toString())),_line(en?'Name':'الاسم',user['name'].toString()),_line(en?'Balance':'الرصيد',NumberFormat('#,##0.00').format(balance)+' SDG'),
  const Divider(),Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[TextButton.icon(onPressed:()=>_shareText(context,_ref(user['account'].toString())),icon:const Icon(Icons.qr_code),label:Text(en?'Payment code':'رمز الدفع السريع')),TextButton.icon(onPressed:()=>_shareText(context,'${user['name']} ${user['account']}'),icon:const Icon(Icons.receipt_long),label:Text(en?'Statement':'كشف الحساب'))])
 ]))) ]));
}
String _ref(String a)=>'10030${a}0001';
Widget _line(String l,String v)=>Padding(padding:const EdgeInsets.symmetric(vertical:11),child:Row(children:[Expanded(child:Text(l,style:const TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text(v,textAlign:TextAlign.end,style:const TextStyle(color:ink)))]));
class TransferMenu extends StatelessWidget {
 final bool en;final VoidCallback onBack,onDirect,onBeneficiary;
 const TransferMenu({super.key,required this.en,required this.onBack,required this.onDirect,required this.onBeneficiary});
 @override Widget build(BuildContext context)=>Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Transfers':'تحويلات',onBack),_menuCard(en?'Transfer to Bank of Khartoum accounts':'تحويل لحسابات بنك الخرطوم',Icons.account_balance,onDirect),_menuCard(en?'Mobile payment / beneficiaries':'الدفع عبر الموبايل',Icons.phone_android,onBeneficiary),_menuCard(en?'Transfer to another bank':'تحويل لبنك آخر',Icons.credit_card,()=>_showUnavailable(context,en))]));
}
Widget _menuCard(String s,IconData i,VoidCallback f)=>InkWell(onTap:f,child:Card(margin:const EdgeInsets.fromLTRB(16,8,16,20),child:Padding(padding:const EdgeInsets.all(22),child:Row(children:[Icon(i,color:deepRed,size:38),const SizedBox(width:20),Expanded(child:Text(s,style:const TextStyle(fontSize:21))),const Icon(Icons.chevron_left,color:deepRed,size:34)]))));
void _showUnavailable(BuildContext c,bool en)=>ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(en?'Not included in this demo':'هذه الخدمة خارج نطاق المحاكاة الحالية')));
class DirectPage extends StatelessWidget {
 final bool en;final VoidCallback onBack;final Function(String) onContinue;
 const DirectPage({super.key,required this.en,required this.onBack,required this.onContinue});
 @override Widget build(BuildContext context){final a=TextEditingController();return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Direct payment':'تحويل لحسابات بنك الخرطوم',onBack),Container(width:double.infinity,color:red,padding:const EdgeInsets.all(18),child:Text(en?'Direct transfer':'دفع مباشر',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:27))),Padding(padding:const EdgeInsets.all(18),child:Column(children:[Field(en?'Enter 7-digit account number':'أدخل رقم الحساب (7 أرقام)',a,keyboard:TextInputType.number,prefix:const Icon(Icons.qr_code)),const SizedBox(height:22),Align(alignment:Alignment.centerLeft,child:SizedBox(width:170,child:GlossButton(en?'Continue':'إرسال',(){final v=a.text.trim();if(!RegExp(r'^2\d{6}$').hasMatch(v)){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(en?'Account must be 7 digits and start with 2':'رقم الحساب يجب أن يتكون من 7 أرقام ويبدأ بـ 2')));return;}onContinue(v);}))) ]))]));}
}
class ConfirmTransferPage extends StatelessWidget {
 final bool en;final String account,name;final VoidCallback onBack;final Function(String,String) onConfirm;
 const ConfirmTransferPage({super.key,required this.en,required this.account,required this.name,required this.onBack,required this.onConfirm});
 @override Widget build(BuildContext context){final amount=TextEditingController(),comment=TextEditingController();return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Transfer to account':'تحويل لحسابات بنك الخرطوم',onBack),Container(width:double.infinity,color:red,padding:const EdgeInsets.all(16),child:Text(en?'Direct payment':'دفع مباشر',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:25))),Padding(padding:const EdgeInsets.all(18),child:Column(children:[
 _line(en?'Account number':'رقم الحساب',_ref(account)),_line(en?'Name':'الاسم',name),_line(en?'Account type':'نوع الحساب','حساب تجريبي'),
 const SizedBox(height:12),Field(en?'Amount in SDG':'أدخل المبلغ بالجنيه السوداني',amount,keyboard:const TextInputType.numberWithOptions(decimal:true)),const SizedBox(height:12),Field(en?'Comment (optional)':'ملاحظات (اختياري)',comment),
 const SizedBox(height:25),Row(children:[Expanded(child:GlossButton(en?'Cancel':'إلغاء',onBack)),const SizedBox(width:22),Expanded(child:GlossButton(en?'Confirm':'تأكيد',()=>onConfirm(amount.text,comment.text)))])
 ]))]));}
}
class BeneficiariesPage extends StatelessWidget {
 final bool en;final List<Map<String,dynamic>> items;final VoidCallback onBack;final Function(String,String) onAdd;
 const BeneficiariesPage({super.key,required this.en,required this.items,required this.onBack,required this.onAdd});
 @override Widget build(BuildContext context){final a=TextEditingController(),n=TextEditingController();return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Mobile payment / beneficiaries':'الدفع عبر الموبايل',onBack),Padding(padding:const EdgeInsets.all(16),child:Column(children:[Field(en?'7-digit account number':'رقم الحساب (7 أرقام)',a,keyboard:TextInputType.number),const SizedBox(height:10),Field(en?'Recipient name':'اسم المستخدم للمستفيد',n),const SizedBox(height:14),GlossButton(en?'Add beneficiary':'إضافة مستفيد',(){if(!RegExp(r'^2\d{6}$').hasMatch(a.text)||n.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(en?'Enter valid account and name':'أدخل رقم حساب صحيحاً والاسم')));return;}onAdd(a.text,n.text.trim());a.clear();n.clear();})])),Expanded(child:ListView(children:items.map((e)=>ListTile(leading:const Icon(Icons.person,color:deepRed),title:Text(e['name']),subtitle:Text(e['account'])).toList()))]));}
}
class TopUpPage extends StatelessWidget {
 final bool en;final VoidCallback onBack;final Function(double) onSubmit;
 const TopUpPage({super.key,required this.en,required this.onBack,required this.onSubmit});
 @override Widget build(BuildContext context){final c=TextEditingController();return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Demo top-up':'شحن الرصيد التجريبي',onBack),Padding(padding:const EdgeInsets.all(20),child:Column(children:[const Icon(Icons.qr_code_2,color:deepRed,size:70),Text(en?'Simulated funds received':'استلام أموال تجريبية',style:const TextStyle(fontSize:24,color:green)),const SizedBox(height:18),Field(en?'Amount (max 3,000,000 SDG)':'أدخل مبلغ الشحن (الحد 3,000,000)',c,keyboard:const TextInputType.numberWithOptions(decimal:true)),const SizedBox(height:20),GlossButton(en?'Receive demo funds':'استلام أموال',(){onSubmit(double.tryParse(c.text.replaceAll(',',''))??0);})]))]));}
}
class ReceiptPage extends StatelessWidget {
 final bool en;final Map<String,dynamic> tx;final VoidCallback onOk,onNew;
 const ReceiptPage({super.key,required this.en,required this.tx,required this.onOk,required this.onNew});
 @override Widget build(BuildContext context)=>Scaffold(body:GreenReceipt(en:en,tx:tx,success:true,onBack:onOk,onNew:onNew));
}
class GreenReceipt extends StatelessWidget {
 final bool en,success;final Map<String,dynamic> tx;final VoidCallback onBack,onNew;
 const GreenReceipt({super.key,required this.en,required this.tx,required this.success,required this.onBack,required this.onNew});
 @override Widget build(BuildContext context){final rows=[if(tx['id']!=null)_r(en?'Transaction number':'رقم العملية',tx['id'].toString()),_r(en?'Date and time':'التاريخ و الزمن',tx['date'].toString()),_r(en?'From account':'من حساب',tx['from'].toString()),_r(en?'To account':'الى حساب',tx['to'].toString()),_r(en?'Recipient name':'إسم المرسل اليه',tx['name'].toString()),_r(en?'Mobile number':'رقم الموبايل','N/A'),_r(en?'Comment':'التعليق',tx['comment'].toString()),_r(en?'Amount':'المبلغ',NumberFormat('#,##0.00').format(tx['amount'])+' SDG')];return Container(decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF62AE10),Color(0xFF16812C)],begin:Alignment.topCenter,end:Alignment.bottomCenter)),child:SafeArea(child:Column(children:[
 const SizedBox(height:26),Container(width:150,height:150,decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle),child:const Icon(Icons.check,color:Color(0xFF20A35A),size:115)),
 const SizedBox(height:25),Text(en?'Transfers':'تحويلات',style:const TextStyle(color:Colors.white,fontSize:30)),const SizedBox(height:22),
 Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:22),child:ListView(shrinkWrap:true,children:rows.map((e)=>Container(height:65,decoration:BoxDecoration(border:Border.all(color:Colors.white,width:1.5),borderRadius:BorderRadius.circular(9)),padding:const EdgeInsets.symmetric(horizontal:13),child:Row(children:[Expanded(child:Text(e.$2,style:const TextStyle(color:Colors.white,fontSize:16))),Expanded(child:Text(e.$1,style:const TextStyle(color:Colors.white,fontSize:16),textAlign:TextAlign.end))]))).toList()))),
 GlossButton(en?'OK':'موافق',onBack,height:58),const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[TextButton.icon(onPressed:onNew,icon:const Icon(Icons.add,color:Colors.white),label:Text(en?'New transfer':'تحويل',style:const TextStyle(color:Colors.white))),TextButton.icon(onPressed:()=>_shareText(context,_receiptText(tx)),icon:const Icon(Icons.person_add,color:Colors.white),label:Text(en?'Add':'إضافة',style:const TextStyle(color:Colors.white)))]),
 _receiptActions(context,tx,en),const SizedBox(height:8),Text(en?'DEMO ONLY — NOT A BANK RECEIPT':'إيصال محاكاة تجريبية — ليس إيصالاً مصرفياً',style:const TextStyle(color:Colors.white70,fontSize:11)),const SizedBox(height:8)
 ])));}
}
(String,String) _r(String a,String b)=>(a,b);
String _receiptText(Map<String,dynamic> tx)=>tx.entries.map((e)=>'${e.key}: ${e.value}').join('\n');
Widget _receiptActions(BuildContext c,Map<String,dynamic> tx,bool en)=>Container(margin:const EdgeInsets.symmetric(horizontal:12),decoration:BoxDecoration(border:Border.all(color:Colors.white,width:1.5),borderRadius:BorderRadius.circular(8)),child:Row(children:[
 Expanded(child:TextButton.icon(onPressed:()=>_shareText(c,_receiptText(tx)),icon:const Icon(Icons.download,color:Colors.white),label:Text(en?'Download':'تحميل',style:const TextStyle(color:Colors.white)))),
 const VerticalDivider(color:Colors.white,width:1),
 Expanded(child:TextButton.icon(onPressed:()=>_printReceipt(tx),icon:const Icon(Icons.print,color:Colors.white),label:Text(en?'Print':'طباعة',style:const TextStyle(color:Colors.white)))),
 const VerticalDivider(color:Colors.white,width:1),
 Expanded(child:TextButton.icon(onPressed:()=>_shareText(c,_receiptText(tx)),icon:const Icon(Icons.share,color:Colors.white),label:Text(en?'Share':'مشاركة',style:const TextStyle(color:Colors.white))))
 ]));
class HistoryPage extends StatelessWidget {
 final bool en;final List<Map<String,dynamic>> items;final VoidCallback onBack;final Function(Map<String,dynamic>) onSelect;
 const HistoryPage({super.key,required this.en,required this.items,required this.onBack,required this.onSelect});
 @override Widget build(BuildContext context){return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Previous transactions':'المعاملات السابقة',onBack),Container(color:Colors.white,padding:const EdgeInsets.all(17),child:Row(children:[Expanded(child:Text(en?'Choose service type':'اختار نوع الخدمة',style:const TextStyle(fontSize:21,color:Colors.black54))),const Icon(Icons.arrow_drop_down,size:32)])),Expanded(child:items.isEmpty?Center(child:Text(en?'No transactions yet':'لا توجد معاملات حتى الآن',style:const TextStyle(color:Colors.black54,fontSize:20))):ListView.builder(itemCount:items.length,itemBuilder:(c,i){final tx=items[i];return Card(margin:const EdgeInsets.fromLTRB(16,8,16,8),elevation:3,child:ListTile(onTap:()=>onSelect(tx),leading:const CircleAvatar(backgroundColor:Colors.white,child:Icon(Icons.account_balance,color:deepRed)),title:Row(children:[Expanded(child:Text(tx['date'].toString(),style:const TextStyle(fontSize:14))),Text('SDG. ${NumberFormat('#,##0.00').format(tx['amount'])}',style:const TextStyle(color:deepRed,fontSize:14))]),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(tx['type'].toString(),style:const TextStyle(color:Colors.black54,fontSize:17)),Text(tx['to'].toString(),style:const TextStyle(color:Colors.black45,fontSize:15))]) ));}))]));}
}
class TransactionPage extends StatelessWidget {
 final bool en;final Map<String,dynamic> tx;final VoidCallback onBack;
 const TransactionPage({super.key,required this.en,required this.tx,required this.onBack});
 @override Widget build(BuildContext context){final rows=[_r(en?'Transaction number':'رقم العملية',tx['id'].toString()),_r(en?'Date and time':'التاريخ والوقت',tx['date'].toString()),_r(en?'Transaction type':'نوع العملية',tx['type'].toString()),_r(en?'Amount':'المبلغ',NumberFormat('#,##0.00').format(tx['amount'])+' SDG'),_r(en?'From':'من',tx['from'].toString()),_r(en?'To':'إلى',tx['to'].toString()),_r(en?'Status':'الحالة',tx['status'].toString()),_r(en?'Recipient name':'إسم المرسل اليه',tx['name'].toString()),_r(en?'Comment':'التعليق',tx['comment'].toString())];return Scaffold(body:Column(children:[const BrandHeader(en:false),BackTitle(en?'Transaction details':'تفاصيل المعاملة',onBack),Expanded(child:ListView(children:rows.map((e)=>Container(height:74,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:ink,width:1),borderRadius:BorderRadius.circular(8)),margin:const EdgeInsets.only(bottom:0),padding:const EdgeInsets.symmetric(horizontal:16),child:Row(children:[Expanded(child:Text(e.$2,style:const TextStyle(fontSize:19))),Expanded(child:Text(e.$1,textAlign:TextAlign.end,style:const TextStyle(fontSize:19)))]))).toList())),_receiptActions(context,tx,en),const SizedBox(height:8)]));}
}
class SummaryPage extends StatelessWidget {
 final bool en;final Map<String,dynamic> user;final List<Map<String,dynamic>> transactions;final VoidCallback onClose;
 const SummaryPage({super.key,required this.en,required this.user,required this.transactions,required this.onClose});
 @override Widget build(BuildContext context){final total=transactions.fold<double>(0,(s,e)=>s+(e['type']=='تحويل إلى حساب آخر'?(e['amount'] as num).toDouble():0));return Scaffold(body:Container(width:double.infinity,decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF65B20E),Color(0xFF147B2A)],begin:Alignment.topCenter,end:Alignment.bottomCenter)),child:SafeArea(child:Column(children:[
 const SizedBox(height:40),const Icon(Icons.power_settings_new,color:Colors.white,size:105),Text(en?'Logged out':'تسجيل خروج',style:const TextStyle(color:Colors.white,fontSize:28)),const SizedBox(height:20),Text(en?'Transaction summary':'ملخص المعاملات',style:const TextStyle(color:Colors.white,fontSize:25)),
 const SizedBox(height:30),_summaryRow(en?'Account':'الحساب',user['account'].toString()),_summaryRow(en?'Transactions':'عدد المعاملات',transactions.length.toString()),_summaryRow(en?'Total transfers':'إجمالي التحويلات',NumberFormat('#,##0.00').format(total)+' SDG'),
 const Spacer(),Text(en?'Thank you for using the demo':'شكراً لاستخدامك المحاكاة المصرفية التجريبية',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:20)),const Spacer(),GlossButton(en?'Close':'إغلاق',onClose,height:62),const SizedBox(height:45),Text('BANKAK DEMO • 2026',style:const TextStyle(color:Colors.white70))
 ]))));}
}
Widget _summaryRow(String l,String v)=>Container(margin:const EdgeInsets.symmetric(horizontal:22),padding:const EdgeInsets.all(16),decoration:BoxDecoration(border:Border.all(color:Colors.white,width:1.5),borderRadius:BorderRadius.circular(8)),child:Row(children:[Expanded(child:Text(v,style:const TextStyle(color:Colors.white,fontSize:18))),Text(l,style:const TextStyle(color:Colors.white,fontSize:18))]));
Future<void> _shareText(BuildContext c,String s) async {await Share.share(s);}
Future<void> _printReceipt(Map<String,dynamic> tx) async {
 final doc=pw.Document();
 doc.addPage(pw.Page(build:(ctx)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
  pw.Text('BANKAK DEMO — SIMULATED RECEIPT',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),
  pw.SizedBox(height:20),...tx.entries.map((e)=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:7),child:pw.Text('${e.key}: ${e.value}')))
 ])));
 await Printing.layoutPdf(onLayout:(format)=>doc.save());
}
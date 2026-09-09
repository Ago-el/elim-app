import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/session.dart';

void main()=>runApp(const ElimApp());

class ElimApp extends StatelessWidget {
  const ElimApp({super.key});
  @override Widget build(BuildContext c)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'ELIM',
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF173B72))),
    home:const Boot()
  );
}

class Boot extends StatefulWidget{const Boot({super.key});@override State<Boot> createState()=>_BootState();}
class _BootState extends State<Boot>{
  @override void initState(){super.initState();go();}
  Future<void> go() async {final ok=await Session.loggedIn();if(!mounted)return;Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ok?const Home():const Login()));}
  @override Widget build(BuildContext c)=>const Scaffold(body:Center(child:CircularProgressIndicator()));
}

class Login extends StatefulWidget{const Login({super.key});@override State<Login> createState()=>_LoginState();}
class _LoginState extends State<Login>{
  final email=TextEditingController(),password=TextEditingController();bool loading=false;
  void msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> login() async {
    if(email.text.trim().isEmpty||password.text.isEmpty){msg('Veuillez renseigner vos identifiants.');return;}
    setState(()=>loading=true);
    try{
      final d=await ApiClient().post('/api/v1/auth/admin',{'email':email.text.trim(),'password':password.text});
      await Session.save(d['access_token'],Map<String,dynamic>.from(d['user']??{}));
      if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const Home()));
    }catch(_){msg('Connexion impossible. Vérifiez l’API et vos identifiants.');}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext c)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(
    padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Column(children:[
      const CircleAvatar(radius:45,child:Icon(Icons.church,size:46)),const SizedBox(height:16),
      const Text('ELIM',style:TextStyle(fontSize:34,fontWeight:FontWeight.w800)),
      const Text('Communauté • Églises • Membres'),const SizedBox(height:30),
      TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),
      const SizedBox(height:14),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Mot de passe')),
      const SizedBox(height:20),SizedBox(width:double.infinity,child:FilledButton(onPressed:loading?null:login,child:Padding(padding:const EdgeInsets.all(14),child:Text(loading?'Connexion…':'Se connecter')))),
      TextButton(onPressed:()=>msg('La récupération OTP est gérée par le fournisseur d’authentification configuré côté serveur.'),child:const Text('Mot de passe oublié ?'))
    ])))
  )));
}

class Home extends StatefulWidget{const Home({super.key});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
  int tab=0;
  final pages=const[Dashboard(),Members(),Churches(),Generic(title:'Messages',icon:Icons.chat_bubble),Profile()];
  @override Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(title:const Text('ELIM')),
    drawer:Drawer(child:ListView(children:[
      const DrawerHeader(decoration:BoxDecoration(color:Color(0xFF173B72)),child:Align(alignment:Alignment.bottomLeft,child:Text('ELIM',style:TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.bold)))),
      for(final x in [
        ['Groupements',Icons.groups],['Prédications',Icons.video_library],['Actualités',Icons.newspaper],
        ['Événements',Icons.event],['Bible & ressources',Icons.menu_book],['Paramètres',Icons.settings]
      ]) ListTile(leading:Icon(x[1] as IconData),title:Text(x[0] as String),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Generic(title:x[0] as String,icon:x[1] as IconData)))),
      const Divider(),ListTile(leading:const Icon(Icons.logout),title:const Text('Déconnexion'),onTap:()async{await Session.clear();if(mounted)Navigator.pushAndRemoveUntil(c,MaterialPageRoute(builder:(_)=>const Login()),(_)=>false);})
    ])),
    body:pages[tab],
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Accueil'),
      NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Membres'),
      NavigationDestination(icon:Icon(Icons.church_outlined),selectedIcon:Icon(Icons.church),label:'Églises'),
      NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'Messages'),
      NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profil')
    ])
  );
}

class Dashboard extends StatelessWidget{const Dashboard({super.key});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Bienvenue dans ELIM',style:TextStyle(fontSize:26,fontWeight:FontWeight.w800)),
  const SizedBox(height:6),const Text('Votre espace communautaire et administratif.'),const SizedBox(height:20),
  GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,children:[
    _card(c,'Membres',Icons.people,const Members()),_card(c,'Églises',Icons.church,const Churches()),
    _card(c,'Prédications',Icons.video_library,const Generic(title:'Prédications',icon:Icons.video_library)),
    _card(c,'Événements',Icons.event,const Generic(title:'Événements',icon:Icons.event))
  ]),
  const SizedBox(height:20),const Card(child:ListTile(leading:Icon(Icons.notifications_active),title:Text('Notifications'),subtitle:Text('Les annonces de votre communauté apparaîtront ici.')))
]);}
Widget _card(BuildContext c,String t,IconData i,Widget p)=>Card(child:InkWell(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>p)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(i,size:38),const SizedBox(height:10),Text(t,style:const TextStyle(fontWeight:FontWeight.w700))])));

class Members extends StatefulWidget{const Members({super.key});@override State<Members> createState()=>_MembersState();}
class _MembersState extends State<Members>{List<dynamic> items=[];bool loading=true;@override void initState(){super.initState();load();}
Future<void> load()async{try{final d=await ApiClient().get('/api/v1/members');if(mounted)setState((){items=d is List?d:(d['items']??[]);loading=false;});}catch(_){if(mounted)setState(()=>loading=false);}}
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Membres')),body:loading?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('Aucun membre disponible.')):RefreshIndicator(onRefresh:load,child:ListView.builder(itemCount:items.length,itemBuilder:(_,i){final m=Map<String,dynamic>.from(items[i]);final n='${m['first_name']??''} ${m['last_name']??''}'.trim();return Card(child:ListTile(leading:CircleAvatar(child:Text(n.isEmpty?'?':n[0])),title:Text(n.isEmpty?'Membre':n),subtitle:Text(m['phone']?.toString()??m['email']?.toString()??'')));})));}

class _ChurchesState extends State<Churches>{
  List<dynamic> items=[];
  bool loading=true;
  bool creating=false;
  
  @override 
  void initState(){
    super.initState();
    load();
  }
  
  Future<void> load()async{
    try{
      final d=await ApiClient().get('/api/v1/churches');
      if(mounted)setState((){
        items=d is List?d:(d['items']??[]);
        loading=false;
      });
    }catch(_){
      if(mounted)setState(()=>loading=false);
    }
  }

  Future<void> createEgliseZAKPOTA() async {
    setState(()=>creating=true);
    try {
      await ApiClient().createChurch("ELIM ZA-KPOTA", "BJ", "ZA-KPOTA");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ELIM ZA-KPOTA créée avec succès!"))
      );
      await load();
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"))
      );
    }
    setState(()=>creating=false);
  }

  @override 
  Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(
      title:const Text('Églises & annexes'),
      actions: [
        IconButton(
          icon: creating? CircularProgressIndicator(color: Colors.white) : Icon(Icons.add),
          onPressed: creating? null : createEgliseZAKPOTA,
        )
      ]
    ),
    body:loading?const Center(child:CircularProgressIndicator()):
    items.isEmpty?Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Text('Aucune église disponible.'),
      SizedBox(height: 20),
      FilledButton(
        onPressed: createEgliseZAKPOTA,
        child: Text("Créer ELIM ZA-KPOTA")
      )
    ])):
    ListView.builder(itemCount:items.length,itemBuilder:(_,i){
      final m=Map<String,dynamic>.from(items[i]);
      return Card(child:ListTile(
        leading:const CircleAvatar(child:Icon(Icons.church)),
        title:Text(m['name']?.toString()??'Église'),
        subtitle:Text(m['city']?.toString()??m['country']?.toString()??'')
      ));
    })
  );
}
class Profile extends StatefulWidget{const Profile({super.key});@override State<Profile> createState()=>_ProfileState();}
class _ProfileState extends State<Profile>{Map<String,String> u={};@override void initState(){super.initState();Session.user().then((v){if(mounted)setState(()=>u=v);});}
@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[const CircleAvatar(radius:44,child:Icon(Icons.person,size:44)),const SizedBox(height:14),Center(child:Text(u['name']??'Membre ELIM',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))),const SizedBox(height:20),Card(child:ListTile(leading:const Icon(Icons.badge),title:const Text('Rôle'),subtitle:Text(u['role']??'member'))),Card(child:ListTile(leading:const Icon(Icons.email),title:const Text('Email'),subtitle:Text(u['email']??'')))]);}

class Generic extends StatelessWidget{final String title;final IconData icon;const Generic({super.key,required this.title,required this.icon});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(title)),body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:70),const SizedBox(height:16),Text(title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Padding(padding:EdgeInsets.all(24),child:Text('Module préparé pour être alimenté par les données et permissions ELIM du serveur.',textAlign:TextAlign.center))])));}

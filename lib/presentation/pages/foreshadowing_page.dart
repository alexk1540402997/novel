import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/foreshadowing.dart';
import '../../domain/services/foreshadowing_service.dart';
import '../pages/novel_architecture_page.dart'; // SelectedNovelProvider

class ForeshadowingPage extends StatefulWidget {
  const ForeshadowingPage({super.key});
  @override
  State<ForeshadowingPage> createState() => _ForeshadowingPageState();
}

class _ForeshadowingPageState extends State<ForeshadowingPage> {
  List<Foreshadowing> _all = [], _filtered = [];
  String _statusFilter = '全部', _search = '';
  bool _loading = false;
  String? _novel;
  final _svc = ForeshadowingService();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final n = context.read<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) { _novel = n; if (n != null) _load(); }
  }

  Future<void> _load() async {
    if (_novel == null) return;
    setState(() => _loading = true);
    _all = await _svc.loadAll(_novel!);
    setState(() { _loading = false; _apply(); });
  }

  void _apply() {
    var l = _all;
    if (_statusFilter != '全部') l = l.where((f) => f.status == _statusFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      l = l.where((f) => f.name.toLowerCase().contains(q) || f.description.toLowerCase().contains(q)).toList();
    }
    // 排序：提醒的排在前面，然后按回收章节排序
    l.sort((a, b) {
      if (a.remind && !b.remind) return -1;
      if (!a.remind && b.remind) return 1;
      return a.reapChapter.compareTo(b.reapChapter);
    });
    setState(() => _filtered = l);
  }

  Future<void> _delete(Foreshadowing f) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认删除'), content: Text('删除伏笔「${f.name}」？'),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')), TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('删除',style:TextStyle(color:Colors.red)))],
    ));
    if (ok == true && _novel != null) { await _svc.delete(_novel!, f.id); _load(); }
  }

  Future<void> _edit({Foreshadowing? existing}) async {
    if (_novel == null) return;
    final isNew = existing == null;
    final f = existing ?? Foreshadowing(id: DateTime.now().millisecondsSinceEpoch.toString(), name: '');
    String name=f.name, desc=f.description, plantNode=f.plantNode, reapNode=f.reapNode;
    int plantCh=f.plantChapter, reapCh=f.reapChapter;
    String status=f.status; bool remind=f.remind;
    String charStr=f.relatedCharacters.join('、'), setStr=f.relatedSettings.join('、'), linkStr=f.linkedIds.join('、'), notes=f.notes;

    final r = await showDialog<Foreshadowing>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text(isNew ? '新增伏笔' : '编辑伏笔'),
      content: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min, crossAxisAlignment:CrossAxisAlignment.stretch, children: [
        TextField(decoration:const InputDecoration(labelText:'伏笔名称*',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:name), onChanged:(v)=>name=v),
        const SizedBox(height:10),
        TextField(decoration:const InputDecoration(labelText:'描述',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:desc), onChanged:(v)=>desc=v, maxLines:2),
        const SizedBox(height:12),
        Text('📍 埋设位置', style:TextStyle(fontWeight:FontWeight.w600,fontSize:14,color:Colors.teal[700])),
        const SizedBox(height:6),
        Row(children:[
          Expanded(child:TextField(decoration:const InputDecoration(labelText:'埋设章节号',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:plantCh>0?plantCh.toString():''), onChanged:(v)=>plantCh=int.tryParse(v)??0, keyboardType:TextInputType.number)),
          const SizedBox(width:10),
          Expanded(child:TextField(decoration:const InputDecoration(labelText:'大纲节点',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:plantNode), onChanged:(v)=>plantNode=v)),
        ]),
        const SizedBox(height:12),
        Text('🎯 回收位置', style:TextStyle(fontWeight:FontWeight.w600,fontSize:14,color:Colors.orange[700])),
        const SizedBox(height:6),
        Row(children:[
          Expanded(child:TextField(decoration:const InputDecoration(labelText:'回收章节号',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:reapCh>0?reapCh.toString():''), onChanged:(v)=>reapCh=int.tryParse(v)??0, keyboardType:TextInputType.number)),
          const SizedBox(width:10),
          Expanded(child:TextField(decoration:const InputDecoration(labelText:'回收节点',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:reapNode), onChanged:(v)=>reapNode=v)),
        ]),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(value:status, decoration:const InputDecoration(labelText:'状态',border:OutlineInputBorder(),isDense:true), items:foreshadowingStatuses.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(), onChanged:(v)=>setD(()=>status=v??'已埋'))),
          const SizedBox(width:10),
          Expanded(child:CheckboxListTile(title:const Text('提醒',style:TextStyle(fontSize:13)), value:remind, onChanged:(v)=>setD(()=>remind=v??false), dense:true, controlAffinity:ListTileControlAffinity.leading)),
        ]),
        const SizedBox(height:10),
        TextField(decoration:const InputDecoration(labelText:'关联角色(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:charStr), onChanged:(v)=>charStr=v),
        const SizedBox(height:10),
        TextField(decoration:const InputDecoration(labelText:'关联设定(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:setStr), onChanged:(v)=>setStr=v),
        const SizedBox(height:10),
        TextField(decoration:const InputDecoration(labelText:'关联伏笔ID(、分隔)',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:linkStr), onChanged:(v)=>linkStr=v),
        const SizedBox(height:10),
        TextField(decoration:const InputDecoration(labelText:'备注',border:OutlineInputBorder(),isDense:true), controller:TextEditingController(text:notes), onChanged:(v)=>notes=v, maxLines:2),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')), FilledButton(onPressed:(){
        if(name.trim().isEmpty){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('请输入名称')));return;}
        final updated = Foreshadowing(id:f.id, name:name.trim(), description:desc, plantChapter:plantCh, plantNode:plantNode, reapChapter:reapCh, reapNode:reapNode, relatedCharacters:charStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(), relatedSettings:setStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(), status:status, linkedIds:linkStr.split('、').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(), remind:remind, notes:notes, createdAt:f.createdAt);
        Navigator.pop(ctx,updated);
      }, child:Text(isNew?'添加':'保存'))],
    )));

    if (r != null && _novel != null) {
      if (isNew) await _svc.add(_novel!, r); else await _svc.update(_novel!, r);
      _load();
    }
  }

  Color _statusColor(String s) { switch(s){ case '已回收': return Colors.green; case '部分揭示': return Colors.orange; default: return Colors.grey; } }
  IconData _statusIcon(String s) { switch(s){ case '已回收': return Icons.check_circle; case '部分揭示': return Icons.remove_circle; default: return Icons.radio_button_unchecked; } }

  @override
  Widget build(BuildContext context) {
    final n = context.watch<SelectedNovelProvider>().selectedNovel;
    if (n != _novel) WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    if (_novel == null) return const Center(child:Text('请先选择一部小说'));

    final pending = _all.where((f)=>f.remind&&f.reapChapter>0&&f.status!='已回收').length;

    return Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,16,16,0), child:Row(children:[
        Expanded(flex:2,child:TextField(controller:_searchCtrl, decoration:InputDecoration(hintText:'搜索伏笔...',prefixIcon:const Icon(Icons.search),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)),isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)), onChanged:(v){_search=v;_apply();})),
        const SizedBox(width:12),
        Expanded(child:DropdownButtonFormField<String>(value:_statusFilter, decoration:InputDecoration(border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)),isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)), items:['全部',...foreshadowingStatuses].map((s)=>DropdownMenuItem(value:s,child:Text(s,style:const TextStyle(fontSize:13)))).toList(), onChanged:(v){setState((){_statusFilter=v??'全部';_apply();});})),
        const SizedBox(width:12),
        FilledButton.icon(onPressed:()=>_edit(), icon:const Icon(Icons.add,size:18), label:const Text('添加')),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8), child:Row(children:[
        _chip('全部',_all.length,Colors.blue),_chip('已埋',_all.where((f)=>f.status=='已埋').length,Colors.grey),_chip('部分揭示',_all.where((f)=>f.status=='部分揭示').length,Colors.orange),_chip('已回收',_all.where((f)=>f.status=='已回收').length,Colors.green),
        if(pending>0) Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4), decoration:BoxDecoration(color:Colors.red.withAlpha(25),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.red.withAlpha(120))), child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.notifications_active,size:14,color:Colors.red),const SizedBox(width:4),Text('$pending个待回收',style:const TextStyle(fontSize:11,color:Colors.red,fontWeight:FontWeight.w500))])),
      ])),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator()):_filtered.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.lightbulb_outline,size:48,color:Colors.grey[400]),const SizedBox(height:12),Text(_all.isEmpty?'伏笔库为空，点击+添加':'没有匹配的伏笔',style:TextStyle(color:Colors.grey[600]))])):ListView.builder(padding:const EdgeInsets.all(16),itemCount:_filtered.length,itemBuilder:(ctx,i)=>_card(_filtered[i]))),
    ]);
  }
  Widget _chip(String l,int n,Color c)=>Container(margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:c.withAlpha(25),borderRadius:BorderRadius.circular(12),border:Border.all(color:c.withAlpha(80))),child:Text('$l: $n',style:TextStyle(fontSize:12,color:c,fontWeight:FontWeight.w500)));

  Widget _card(Foreshadowing f) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _statusColor(f.status).withAlpha(60))),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _edit(existing: f),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_statusIcon(f.status), size: 20, color: _statusColor(f.status)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(f.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              if (f.remind)
                const Icon(Icons.notifications_active, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: _statusColor(f.status).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _statusColor(f.status).withAlpha(80))),
                  child: Text(f.status,
                      style: TextStyle(fontSize: 11, color: _statusColor(f.status)))),
              PopupMenuButton<String>(
                  iconSize: 18,
                  onSelected: (a) {
                    if (a == 'edit') _edit(existing: f);
                    if (a == 'delete') _delete(f);
                  },
                  itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Text('编辑')),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除', style: TextStyle(color: Colors.red))),
                      ]),
            ]),
            if (f.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(f.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                if (f.plantChapter > 0) _tag('埋:第${f.plantChapter}章', Colors.teal),
                if (f.reapChapter > 0) _tag('收:第${f.reapChapter}章', Colors.orange),
                if (f.plantNode.isNotEmpty) _tag(f.plantNode, Colors.grey),
                ...f.relatedCharacters.map((c) => _tag(c, Colors.blue)),
                ...f.relatedSettings.map((s) => _tag(s, Colors.purple)),
                if (f.linkedIds.isNotEmpty) _tag('关联${f.linkedIds.length}个伏笔', Colors.indigo),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tag(String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withAlpha(20), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, color: c)));
}

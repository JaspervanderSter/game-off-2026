extends Node2D
## Procedural island geometry from the approved ascending-islands concept.
const SkyCycle := preload("res://scripts/ui/day_night_sky.gd")
var biome := 0
var cloud_color := Color("d1dccf")
const GOLD := Color("ddba70")
const INK := Color("49372e")
const GREEN := Color("536b4b")
const PURPLE := Color("543865")
func poly(points: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in points: pts.append(Vector2(p[0], p[1]))
	draw_colored_polygon(pts, col)
func line(a: Vector2, b: Vector2, col: Color, w: float = 2) -> void:
	Shapes.line(self, a, b, col, w)
func disc(p: Vector2, r: float, col: Color) -> void:
	Shapes.circle(self, p, r, col)
func oval(p: Vector2, rx: float, ry: float, col: Color) -> void:
	Shapes.ellipse(self, p, rx, ry, col)
func ring(p: Vector2, r: float, col: Color, w: float = 2) -> void:
	Shapes.arc(self, p, r, 0, TAU, 64, col, w)
func tree(p: Vector2, s: float, col: Color = GREEN) -> void:
	line(p + Vector2(0, -12) * s, p + Vector2(0, 13) * s, INK, 6 * s)
	poly([[p.x-22*s,p.y],[p.x,p.y-58*s],[p.x+22*s,p.y]], col.darkened(0.12))
	poly([[p.x-17*s,p.y-19*s],[p.x,p.y-67*s],[p.x+17*s,p.y-19*s]], col)
func grove(p: Vector2, count: int, s: float) -> void:
	for i in count:
		var q := p + Vector2(fmod(i * 47.0, 137) - 60, fmod(i * 31.0, 75)) * s
		tree(q, s * (0.7 + (i % 3) * 0.14))
func house(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p + Vector2(-24,-29)*s, Vector2(48,36)*s), Color("c9b58b"))
	poly([[p.x-31*s,p.y-28*s],[p.x,p.y-56*s],[p.x+31*s,p.y-28*s]], Color("805544"))
	draw_rect(Rect2(p+Vector2(-5,-14)*s,Vector2(10,21)*s), INK)
	draw_rect(Rect2(p+Vector2(11,-20)*s,Vector2(8,8)*s), GOLD)
func city() -> void:
	# Paved streets, a dense roofline and a fortified gate distinguish the town.
	poly([[-194,-25],[-140,-69],[110,-62],[190,-15],[168,61],[-130,67]], Color("99958a"))
	line(Vector2(-160,14),Vector2(150,20),Color("c4bda9"),14)
	line(Vector2(-5,-64),Vector2(-5,64),Color("c4bda9"),16)
	# Rear curtain wall, with its towers behind the houses.
	wall(Vector2(-178,-39),Vector2(180,-39),29)
	city_tower(Vector2(-178,-30),0.88)
	city_tower(Vector2(178,-30),0.88)
	for p in [Vector2(-132,-45),Vector2(-82,-61),Vector2(80,-57),Vector2(132,-32)]:
		house(p,0.88)
		# Exposed timber and a second warm window below the pitched roof.
		line(p+Vector2(-19,-27),p+Vector2(-19,5),Color("755744"),2)
		line(p+Vector2(-19,-8),p+Vector2(19,-8),Color("755744"),2)
	# The keep rises above the roofs without covering the encounter icons.
	draw_rect(Rect2(-36,-117,70,74),Color("a7a49d"))
	draw_rect(Rect2(15,-117,19,74),Color("817d79"))
	for x in [-36,-18,0,18]:
		draw_rect(Rect2(x,-126,14,14),Color("b5b0a4"))
	for x in [-20,5]:
		draw_rect(Rect2(x,-97,8,17),Color("554b44"))
	poly([[-29,-48],[-29,-73],[-15,-83],[-1,-73],[-1,-48]],Color("62574b"))
	# Lower houses create a city silhouette rather than three isolated cottages.
	house(Vector2(-152,-4),0.73)
	house(Vector2(153,12),0.7)
	wall(Vector2(-181,53),Vector2(-35,65),23)
	wall(Vector2(35,65),Vector2(181,53),23)
	city_tower(Vector2(-185,51),0.8)
	city_tower(Vector2(185,51),0.8)
	city_tower(Vector2(-33,60),0.67)
	city_tower(Vector2(33,60),0.67)
	# A dark arch and red banners make the entrance readable without lettering.
	draw_rect(Rect2(-23,38,46,38),Color("8a8479"))
	poly([[-15,76],[-15,52],[-9,44],[9,44],[15,52],[15,76]],Color("4e4238"))
	for x in [-57,47]:
		poly([[x,15],[x+11,15],[x+11,41],[x+5,37],[x,41]],Color("96504b"))

func wall(a: Vector2, b: Vector2, height: float) -> void:
	draw_colored_polygon(PackedVector2Array([a-Vector2(0,height),b-Vector2(0,height),b,a]),Color("aaa394"))
	line(a,b,Color("797367"),3)
	var count := maxi(2,roundi(a.distance_to(b)/16))
	for i in count:
		var p := a.lerp(b,i/float(count-1))-Vector2(0,height)
		draw_rect(Rect2(p-Vector2(5,7),Vector2(10,10)),Color("b8b1a1"))

func city_tower(p: Vector2, s: float) -> void:
	draw_rect(Rect2(p+Vector2(-15,-47)*s,Vector2(30,51)*s),Color("b4ad9e"))
	draw_rect(Rect2(p+Vector2(5,-47)*s,Vector2(10,51)*s),Color("888278"))
	for x in [-15,-3,9]:
		draw_rect(Rect2(p+Vector2(x,-55)*s,Vector2(9,12)*s),Color("c0b8a7"))
	draw_rect(Rect2(p+Vector2(-4,-31)*s,Vector2(7,14)*s),Color("5e5449"))
func tower(p: Vector2, s: float) -> void:
	oval(p+Vector2(0,8)*s,56*s,15*s,Color(0.12,0.07,0.17,0.3))
	poly([[p.x-28*s,p.y],[p.x-22*s,p.y-105*s],[p.x+22*s,p.y-105*s],[p.x+28*s,p.y]], Color("78617d"))
	poly([[p.x+8*s,p.y],[p.x+8*s,p.y-105*s],[p.x+22*s,p.y-105*s],[p.x+28*s,p.y]], PURPLE)
	poly([[p.x-38*s,p.y-100*s],[p.x,p.y-154*s],[p.x+38*s,p.y-100*s]], Color("513060"))
	line(p+Vector2(-38,-100)*s,p+Vector2(38,-100)*s,GOLD,3*s)
	for y in [-82,-48]:
		draw_rect(Rect2(p+Vector2(-5,y)*s,Vector2(10,17)*s),GOLD)
	Icons.star(self,p+Vector2(0,-129)*s,9*s,GOLD)
	draw_rect(Rect2(p+Vector2(-9,-24)*s,Vector2(18,24)*s),Color("342339"))
func rock(p: Vector2, s: float, col: Color) -> void:
	poly([[p.x-15*s,p.y],[p.x+9*s,p.y-7*s],[p.x+20*s,p.y+4*s],[p.x+2*s,p.y+34*s]],col)
	poly([[p.x+9*s,p.y-7*s],[p.x+20*s,p.y+4*s],[p.x+2*s,p.y+34*s]],col.darkened(0.3))
func floating(p: Vector2, rx: float, ry: float, depth: float, terrain: Color, magic := false) -> void:
	# Deep, asymmetric rock masses and separate shards make the void visible.
	var stone := Color("74615b") if not magic else Color("756381")
	poly([[p.x-rx,p.y],[p.x-rx*.7,p.y+ry+depth*.2],[p.x-rx*.38,p.y+ry+depth*.78],[p.x-rx*.13,p.y+ry+depth*.63],[p.x+rx*.12,p.y+ry+depth],[p.x+rx*.38,p.y+ry+depth*.46],[p.x+rx*.7,p.y+ry+depth*.37],[p.x+rx,p.y]],stone)
	poly([[p.x-rx,p.y],[p.x-rx*.3,p.y+ry*.65],[p.x-rx*.38,p.y+ry+depth*.78],[p.x-rx*.7,p.y+ry+depth*.2]],stone.lightened(.12))
	poly([[p.x-rx*.3,p.y+ry*.65],[p.x+rx*.15,p.y+ry*.8],[p.x+rx*.12,p.y+ry+depth],[p.x-rx*.13,p.y+ry+depth*.63]],stone.darkened(.23))
	poly([[p.x+rx*.15,p.y+ry*.8],[p.x+rx,p.y],[p.x+rx*.7,p.y+ry+depth*.37],[p.x+rx*.38,p.y+ry+depth*.46],[p.x+rx*.12,p.y+ry+depth]],stone.darkened(.34))
	var top := [[p.x-rx,p.y],[p.x-rx*.82,p.y-ry*.65],[p.x-rx*.35,p.y-ry],[p.x+rx*.12,p.y-ry*.87],[p.x+rx*.7,p.y-ry*.8],[p.x+rx,p.y-ry*.15],[p.x+rx*.88,p.y+ry*.55],[p.x+rx*.25,p.y+ry],[p.x-rx*.3,p.y+ry*.85],[p.x-rx*.85,p.y+ry*.5]]
	poly(top,terrain.darkened(.28))
	var grass := []
	for v in top: grass.append([v[0],v[1]-8])
	poly(grass,terrain)
	for i in 4:
		var q := p+Vector2((i-1.5)*rx*.46,ry+depth*(.55+(i%2)*.38)+24)
		rock(q,.35+(i%3)*.15,stone)
	if magic:
		for x in [-0.42,0.28]:
			var q := p+Vector2(x*rx,ry+depth*.35)
			poly([[q.x-7,q.y-15],[q.x,q.y-29],[q.x+7,q.y-15],[q.x,q.y+8]],Color("b391cf"))
	else:
		for i in 4:
			var q := p+Vector2(-rx*.65+i*rx*.32,ry*.65)
			line(q,q+Vector2(4,depth*.23+(i%2)*15),Color("61704b"),3)

func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var terrain: Color = [Color("718353"), Color("aaa28f"), Color("8d789b")][biome]
	floating(Vector2.ZERO, 240, 96, 150, terrain, biome == 2)
	match biome:
		0:
			grove(Vector2(-120, -28), 8, 0.83)
			grove(Vector2(150, -8), 5, 0.65)
			# Water spills into the clouds beneath the island.
			poly([[-163,60],[-141,64],[-146,212],[-159,212]], Color("86b7b6"))
			line(Vector2(-155,64),Vector2(-151,207),Color("b7d3c5"),3)
			SkyCycle.cloud(self,Vector2(-150,218),.4,cloud_color)
		1:
			city()
		2:
			tower(Vector2(0,-15),1.05)
			for p in [Vector2(-190,35),Vector2(178,-15)]:
				poly([[p.x-9,p.y],[p.x,p.y-34],[p.x+9,p.y],[p.x,p.y+9]],Color("b192c4"))

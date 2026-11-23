class_name PhysicsLayers
extends RefCounted
## 충돌 층 번호 (비트 값). 프로젝트 설정의 층 이름과 맞춘다.

const WORLD: int = 1        ## 길, 선반
const PORTER: int = 2       ## 주인공 몸, 지게
const ITEMS: int = 4        ## 상품
const DEBRIS: int = 8       ## 깨진 조각 (길하고만 부딪힘)

const ITEM_MASK: int = WORLD | PORTER | ITEMS
const DEBRIS_MASK: int = WORLD

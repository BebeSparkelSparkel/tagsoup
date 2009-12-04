
module TagSoup.Generate.Convert(input,output) where

import TagSoup.Generate.Type
import TagSoup.Generate.HSE
import Data.List


input :: [Decl] -> [Func]
input = map inFunc

inFunc (PatBind _ (PVar (Ident name)) Nothing (UnGuardedRhs bod) (BDecls [])) =
    case bod of
        Lambda _ ps x -> Func name (map fromPVar ps) (inExpr x)
        _ -> Func name [] (inExpr bod)
inFunc x = error $ show x

inExpr (Paren x) = inExpr x
inExpr (Var (UnQual (Ident x))) = eVar x
inExpr (Con (UnQual (Ident x))) = eCon x
inExpr (App x y) = eApp (inExpr x) (inExpr y)
inExpr (Let (BDecls xs) y) = unrecLet [(x,inExpr y) | PatBind _ (PVar (Ident x)) _ (UnGuardedRhs y) (BDecls []) <- xs] $ inExpr y
inExpr (Case x ys) = eCase (inExpr x) [(inPatt p, inExpr x) | Alt _ p (UnGuardedAlt x) _ <- ys]
inExpr (Lit x) = eLit x
inExpr x = error $ show ("inExpr",x)


unrecLet :: [(String, Expr)] -> Expr -> Expr
unrecLet xy z | null xy = z
              | null now = error $ "Recursive let: " ++ prettyPrint (outExpr $ eLet xy z)
              | otherwise = eLet now $ unrecLet next z
    where (now,next) = partition (disjoint xs . freeVars . snd) xy
          xs = map fst xy


inPatt (PApp (UnQual (Ident c)) vs) = Patt c (map fromPVar vs)
inPatt PWildCard = PattAny
inPatt (PParen x) = inPatt x
inPatt (PLit x) = PattLit x
inPatt x = error $ show ("inPatt",x)


output :: [Func] -> [Decl]
output = map outFunc

outFunc (Func x y z) = PatBind sl (pvar x) Nothing (UnGuardedRhs $ (if null y then id else Lambda sl (map pvar y)) (outExpr z)) (BDecls [])

outExpr (ECon x) = con x
outExpr (ELit x) = Lit x
outExpr (EVar x) = var x
outExpr (EApp _ x y) = Paren $ App (outExpr x) (outExpr y)
outExpr (ECase _ on alts) = Paren $ Case (outExpr on) [Alt sl (outPatt p) (UnGuardedAlt $ outExpr x) (BDecls []) | (p,x) <- alts]
outExpr (ELet _ xs y) = Paren $ Let (BDecls [PatBind sl (pvar a) Nothing (UnGuardedRhs $ outExpr b) (BDecls []) | (a,b) <- xs]) (outExpr y)

outPatt (Patt c vs) = PApp (UnQual $ Ident c) (map pvar vs)
outPatt PattAny = PWildCard
outPatt (PattLit x) = PLit x

{-

data Func = Func Var [Var] Expr

data Expr = EApp Expr Expr
          | ELet [(Var,Expr)] Expr
          | ECase Var [((Con, [Var]),Expr)]
          | EVar Var
          | ECon Con
-}


fromPVar (PVar (Ident x)) = x

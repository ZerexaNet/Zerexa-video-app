"use client";

/**
 * Mobile-friendly side navigation drawer.
 *
 * Visible only on small screens (controlled by AppHeader). Lists
 * categories and primary destinations, mirroring the desktop
 * category strip.
 */

import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import {
  CompassIcon,
  FireIcon,
  BellIcon,
  UserIcon,
  TvIcon,
  Logo,
} from "@/components/icons";
import { useRoute } from "@/lib/route";

interface AppNavProps {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  categories: { root: string; label: string }[];
}

export function AppNav({ open, onOpenChange, categories }: AppNavProps) {
  const { goHome, goCategory, goProfile } = useRoute();

  const go = (fn: () => void) => () => {
    fn();
    onOpenChange(false);
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="left" className="w-72 p-0">
        <SheetHeader className="border-b border-border px-4 py-3">
          <SheetTitle className="flex items-center gap-2">
            <Logo size={28} />
            <span>Zerexa Video</span>
          </SheetTitle>
        </SheetHeader>

        <div className="flex flex-col gap-1 px-2 py-3">
          <Button
            variant="ghost"
            className="justify-start"
            onClick={go(goHome)}
          >
            <CompassIcon size={18} className="mr-2" />
            推荐
          </Button>
          <Button
            variant="ghost"
            className="justify-start"
            onClick={go(() => useRoute.getState().goSearch(""))}
          >
            <FireIcon size={18} className="mr-2" />
            热门
          </Button>
          <Button
            variant="ghost"
            className="justify-start"
            onClick={go(goProfile)}
          >
            <UserIcon size={18} className="mr-2" />
            个人中心
          </Button>
          <Button
            variant="ghost"
            className="justify-start"
            onClick={go(goHome)}
          >
            <BellIcon size={18} className="mr-2" />
            公告
          </Button>
          <Button
            variant="ghost"
            className="justify-start"
            onClick={go(goHome)}
          >
            <TvIcon size={18} className="mr-2" />
            公投
          </Button>
        </div>

        <div className="mt-2 border-t border-border px-4 py-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          分类
        </div>
        <div className="flex flex-col gap-0.5 px-2 pb-4">
          {categories.map((c) => (
            <Button
              key={c.root}
              variant="ghost"
              className="justify-start text-sm"
              onClick={go(() => goCategory(c.root))}
            >
              {c.label}
            </Button>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  );
}

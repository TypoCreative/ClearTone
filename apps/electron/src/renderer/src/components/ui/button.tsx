import * as React from "react";

import { cn } from "../../lib/utils";

type ButtonVariant = "default" | "secondary" | "outline" | "ghost" | "destructive";
type ButtonSize = "default" | "sm" | "lg" | "icon";

const baseClassName =
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 ring-offset-background";

const variantClassNames: Record<ButtonVariant, string> = {
  default: "bg-primary text-primary-foreground shadow-sm hover:bg-primary/90",
  secondary: "border border-border/60 bg-card/40 text-foreground shadow-sm backdrop-blur-md hover:bg-card/55",
  outline: "border border-border/60 bg-background/30 text-foreground backdrop-blur-md hover:bg-card/40",
  ghost: "text-foreground hover:bg-card/40 hover:text-foreground",
  destructive: "bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90"
};

const sizeClassNames: Record<ButtonSize, string> = {
  default: "h-10 px-4 py-2",
  sm: "h-9 rounded-md px-3",
  lg: "h-11 rounded-md px-8",
  icon: "h-10 w-10"
};

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
};

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "default", size = "default", ...props }, ref) => {
    return (
      <button
        className={cn(baseClassName, variantClassNames[variant], sizeClassNames[size], className)}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

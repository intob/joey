---
title: "Automated secret rotation"
description: "Writing a program for staged secret rotation of many apps."
date: 2024-03-15
---
I was recently tasked with writing a program to execute staged secret rotation of any app.

The core interface I ended up with:
```go
// V represents a Secret Version
type V interface {
	GenerateNext(ctx context.Context) (V, error)
	UpdateApp(ctx context.Context, pending V) error
	Test(ctx context.Context) error
}
```

Types that implement this interface can be rotated automatically by the application. The staged rotation (including rollback) is abstracted into a separate package.

Developers are happy because they can easily rotate their app's secrets, whether DB password, elliptic curve key, or shared secret.
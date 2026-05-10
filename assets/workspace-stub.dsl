workspace "Starter" "Replace with your own system" {

  model {
    paymentProvider = softwareSystem "Payment Provider" "External REST API" {
      tags "External"
    }

    checkout = softwareSystem "Checkout" {
      orders = container "Orders Service"
      ordersRepo = container "Orders Repo" "" "" {
        tags "repo"
      }
      ordersDb = container "Orders DB" "PostgreSQL" "PostgreSQL"
      paymentAcl = container "Payment ACL" "Wraps payment_provider" "" {
        tags "acl"
      }

      orders -> ordersRepo
      ordersRepo -> ordersDb "PostgreSQL"
      orders -> paymentAcl "REST"
    }

    paymentAcl -> paymentProvider "REST"
  }

  views {
    container checkout {
      include *
      autolayout lr
    }
  }
}
